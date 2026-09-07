import '../../../core/utils/fecha_es.dart';
import '../../transactions/data/transaccion.dart';

/// Los 3 periodos que puede navegar Reportes. No incluye "día" (esa
/// granularidad ya la resuelve Lucy por chat, ver `consultar_gasto_periodo`
/// en CLAUDE.md) — para un reporte visual, semana/mes/año son los cortes
/// que de verdad tienen sentido para ver tendencias.
enum TipoPeriodo { semana, mes, anio }

/// Un rango de fechas concreto para un `TipoPeriodo`, ya resuelto:
/// `desde` (incluido) a `hasta` (excluido) — mismo criterio "ventana medio
/// abierta" que usa el resto de la app (ver `ResumenGastos.calcular`,
/// `AsistenteRepository._responderConsultaGasto`).
class RangoPeriodo {
  const RangoPeriodo({
    required this.desde,
    required this.hasta,
    required this.etiqueta,
    required this.esActual,
  });

  final DateTime desde;
  final DateTime hasta;
  final String etiqueta;
  // Si es el periodo en curso (offset 0) — muestra la insignia "EN CURSO".
  final bool esActual;
}

/// Calcula el rango de fechas de un periodo dado un desplazamiento respecto
/// a "ahora": `offset` 0 = el periodo actual, -1 = el anterior, +1 = el
/// siguiente (nunca se navega al futuro desde la UI, pero la función no lo
/// impide — quien la llama decide el límite).
RangoPeriodo calcularRangoPeriodo(TipoPeriodo tipo, int offset) {
  final hoy = DateTime.now();
  switch (tipo) {
    case TipoPeriodo.semana:
      final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
      // Semana de lunes a domingo — mismo criterio que ya usa
      // `_responderConsultaGasto` para "esta semana".
      final inicioSemanaActual = hoySinHora.subtract(
        Duration(days: hoy.weekday - 1),
      );
      final desde = inicioSemanaActual.add(Duration(days: 7 * offset));
      final hasta = desde.add(const Duration(days: 7));
      final hastaInclusive = hasta.subtract(const Duration(days: 1));
      final mismomMes = desde.month == hastaInclusive.month;
      final etiqueta = mismomMes
          ? '${desde.day}–${hastaInclusive.day} ${mesCapitalizado(desde.month)}'
          : '${desde.day} ${mesCapitalizado(desde.month)} – ${hastaInclusive.day} ${mesCapitalizado(hastaInclusive.month)}';
      return RangoPeriodo(
        desde: desde,
        hasta: hasta,
        etiqueta: etiqueta,
        esActual: offset == 0,
      );

    case TipoPeriodo.mes:
      final mesActual = DateTime(hoy.year, hoy.month, 1);
      final desde = DateTime(mesActual.year, mesActual.month + offset, 1);
      final hasta = DateTime(desde.year, desde.month + 1, 1);
      return RangoPeriodo(
        desde: desde,
        hasta: hasta,
        etiqueta: '${mesCapitalizado(desde.month)} ${desde.year}',
        esActual: offset == 0,
      );

    case TipoPeriodo.anio:
      final desde = DateTime(hoy.year + offset, 1, 1);
      final hasta = DateTime(desde.year + 1, 1, 1);
      return RangoPeriodo(
        desde: desde,
        hasta: hasta,
        etiqueta: '${desde.year}',
        esActual: offset == 0,
      );
  }
}

/// Suma bruta por categoría de un solo `tipo` (gasto O ingreso, nunca los
/// dos netos entre sí) dentro de `[desde, hasta)`, excluyendo transferencias
/// — a diferencia de `ResumenGastos.calcular` (que neta un reembolso contra
/// su gasto original en la MISMA categoría), aquí no aplica: ya se filtró a
/// un solo tipo, así que no hay nada que netear. Se usa para el desglose de
/// "Ingresos" en Reportes, donde `ResumenGastos` no encaja (esa neteada es
/// un concepto específico de gasto, ver su propio doc comment).
Map<String, double> totalPorCategoria(
  List<Transaccion> transacciones,
  TipoTransaccion tipo, {
  required DateTime desde,
  required DateTime hasta,
}) {
  final porCategoria = <String, double>{};
  for (final t in transacciones) {
    if (t.esTransferencia || t.tipo != tipo) continue;
    if (t.fecha.isBefore(desde) || !t.fecha.isBefore(hasta)) continue;
    porCategoria.update(
      t.categoria,
      (v) => v + t.monto,
      ifAbsent: () => t.monto,
    );
  }
  final entradas = porCategoria.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {for (final e in entradas) e.key: e.value};
}

/// Suma bruta de un solo `tipo` dentro de `[desde, hasta)`, sin desglosar
/// por categoría — para las tarjetas de "Gastos Totales"/"Ingresos" de
/// Reportes. Excluye transferencias (no son gasto ni ingreso real).
double totalPeriodo(
  List<Transaccion> transacciones,
  TipoTransaccion tipo, {
  required DateTime desde,
  required DateTime hasta,
}) {
  var total = 0.0;
  for (final t in transacciones) {
    if (t.esTransferencia || t.tipo != tipo) continue;
    if (t.fecha.isBefore(desde) || !t.fecha.isBefore(hasta)) continue;
    total += t.monto;
  }
  return total;
}

/// Un tramo del gráfico de "Flujo de efectivo": su etiqueta (ej. "Lun",
/// "Sem 2", "Ene") y cuánto se ingresó/gastó (bruto, sin netear) en ese tramo.
typedef BucketFlujo = ({String etiqueta, double ingreso, double gasto});

const _diasSemanaEs = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _mesesAbreviados = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

/// Divide un `RangoPeriodo` en tramos para el gráfico de barras: por día si
/// es una semana, por semana-del-mes si es un mes, por mes si es un año.
/// `transacciones` puede traer movimientos fuera del rango (ej. porque
/// también se pidió el periodo anterior para comparar) — cada tramo filtra
/// los suyos por fecha.
List<BucketFlujo> calcularBuckets(
  TipoPeriodo tipo,
  RangoPeriodo rango,
  List<Transaccion> transacciones,
) {
  List<(DateTime, DateTime, String)> tramos;
  switch (tipo) {
    case TipoPeriodo.semana:
      tramos = List.generate(7, (i) {
        final dia = rango.desde.add(Duration(days: i));
        return (dia, dia.add(const Duration(days: 1)), _diasSemanaEs[i]);
      });
    case TipoPeriodo.mes:
      tramos = [];
      var inicioTramo = rango.desde;
      var numero = 1;
      while (inicioTramo.isBefore(rango.hasta)) {
        final finTramo = inicioTramo.add(const Duration(days: 7)).isBefore(
              rango.hasta,
            )
            ? inicioTramo.add(const Duration(days: 7))
            : rango.hasta;
        tramos.add((inicioTramo, finTramo, 'Sem $numero'));
        inicioTramo = finTramo;
        numero++;
      }
    case TipoPeriodo.anio:
      tramos = List.generate(12, (i) {
        final inicioMes = DateTime(rango.desde.year, i + 1, 1);
        final finMes = DateTime(rango.desde.year, i + 2, 1);
        return (inicioMes, finMes, _mesesAbreviados[i]);
      });
  }

  return [
    for (final (inicio, fin, etiqueta) in tramos)
      (
        etiqueta: etiqueta,
        ingreso: totalPeriodo(
          transacciones,
          TipoTransaccion.ingreso,
          desde: inicio,
          hasta: fin,
        ),
        gasto: totalPeriodo(
          transacciones,
          TipoTransaccion.gasto,
          desde: inicio,
          hasta: fin,
        ),
      ),
  ];
}
