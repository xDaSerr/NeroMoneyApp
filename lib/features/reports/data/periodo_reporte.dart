import '../../../core/utils/fecha_es.dart';
import '../../transactions/data/transaccion.dart';

/// Los 3 periodos que puede navegar Reportes. No incluye "día" (esa
/// granularidad ya la resuelve Lucy por chat, ver `consultar_gasto_periodo`
/// en CLAUDE.md) — para un reporte visual, semana/mes/año son los cortes
/// que de verdad tienen sentido para ver tendencias.
enum TipoPeriodo { dia, semana, mes, anio }

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
    case TipoPeriodo.dia:
      final desde = DateTime(hoy.year, hoy.month, hoy.day + offset);
      return RangoPeriodo(
        desde: desde,
        hasta: DateTime(desde.year, desde.month, desde.day + 1),
        etiqueta: switch (offset) {
          0 => 'Hoy',
          -1 => 'Ayer',
          _ => fechaCorta(desde),
        },
        esActual: offset == 0,
      );
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
    if (t.esMovimientoInterno || t.tipo != tipo) continue;
    if (t.fecha.isBefore(desde) || !t.fecha.isBefore(hasta)) continue;
    porCategoria.update(
      t.categoria,
      (v) => v + t.montoPrincipal,
      ifAbsent: () => t.montoPrincipal,
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
    if (t.esMovimientoInterno || t.tipo != tipo) continue;
    if (t.fecha.isBefore(desde) || !t.fecha.isBefore(hasta)) continue;
    total += t.montoPrincipal;
  }
  return total;
}

/// Un tramo del gráfico de "Flujo de efectivo": su etiqueta (ej. "Lun",
/// "Sem 2", "Ene") y cuánto se ingresó/gastó (bruto, sin netear) en ese tramo.
typedef BucketFlujo = ({String etiqueta, double ingreso, double gasto});

const _diasSemanaEs = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _mesesAbreviados = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

/// "13 nov 2026".
String fechaCorta(DateTime f) =>
    '${f.day} ${_mesesAbreviados[f.month - 1].toLowerCase()} ${f.year}';

/// Cómo se reparte el periodo en la gráfica de flujo.
enum Tramo {
  horas('Ingresos y gastos por hora'),
  dia('Ingresos y gastos por día'),
  semana('Ingresos y gastos por semana'),
  mes('Ingresos y gastos por mes');

  const Tramo(this.descripcion);
  final String descripcion;
}

/// Lo que eligió el usuario en Reportes: un día, semana, mes o año
/// (navegable con < >), o un rango personalizado "del día A al día B".
class SeleccionPeriodo {
  const SeleccionPeriodo(this.tipo, [this.offset = 0]) : personalizado = null;

  /// [desde] y [hasta] son días completos (ambos incluidos).
  SeleccionPeriodo.rango(DateTime desde, DateTime hasta)
    : tipo = TipoPeriodo.dia,
      offset = 0,
      personalizado = (
        DateTime(desde.year, desde.month, desde.day),
        DateTime(hasta.year, hasta.month, hasta.day + 1),
      );

  final TipoPeriodo tipo;
  final int offset;

  /// [desde, hasta) de un rango elegido en el calendario; null = por tipo.
  final (DateTime, DateTime)? personalizado;

  bool get esPersonalizado => personalizado != null;

  RangoPeriodo get rango {
    final p = personalizado;
    if (p == null) return calcularRangoPeriodo(tipo, offset);
    final (desde, hasta) = p;
    final ultimo = hasta.subtract(const Duration(days: 1));
    final hoy = DateTime.now();
    return RangoPeriodo(
      desde: desde,
      hasta: hasta,
      etiqueta: desde.year == ultimo.year
          ? '${desde.day} ${_mesesAbreviados[desde.month - 1].toLowerCase()} – '
                '${fechaCorta(ultimo)}'
          : '${fechaCorta(desde)} – ${fechaCorta(ultimo)}',
      esActual: !hoy.isBefore(desde) && hoy.isBefore(hasta),
    );
  }

  int get _dias {
    final r = rango;
    return DateTime.utc(
      r.hasta.year,
      r.hasta.month,
      r.hasta.day,
    ).difference(DateTime.utc(r.desde.year, r.desde.month, r.desde.day)).inDays;
  }

  /// El periodo anterior del mismo tamaño (para < y para comparar).
  SeleccionPeriodo get previa {
    final p = personalizado;
    if (p == null) return SeleccionPeriodo(tipo, offset - 1);
    final dias = _dias;
    return SeleccionPeriodo.rango(
      DateTime(p.$1.year, p.$1.month, p.$1.day - dias),
      DateTime(p.$1.year, p.$1.month, p.$1.day - 1),
    );
  }

  SeleccionPeriodo get siguiente {
    final p = personalizado;
    if (p == null) return SeleccionPeriodo(tipo, offset + 1);
    final dias = _dias;
    return SeleccionPeriodo.rango(
      p.$2,
      DateTime(p.$2.year, p.$2.month, p.$2.day + dias - 1),
    );
  }

  /// No se navega al futuro (no tiene movimientos).
  bool get puedeAvanzar => !siguiente.rango.desde.isAfter(DateTime.now());

  Tramo get tramo {
    if (personalizado == null) {
      return switch (tipo) {
        TipoPeriodo.dia => Tramo.horas,
        TipoPeriodo.semana => Tramo.dia,
        TipoPeriodo.mes => Tramo.semana,
        TipoPeriodo.anio => Tramo.mes,
      };
    }
    final dias = _dias;
    return dias <= 1
        ? Tramo.horas
        : dias <= 14
        ? Tramo.dia
        : dias <= 92
        ? Tramo.semana
        : Tramo.mes;
  }
}

/// Divide el periodo elegido en tramos para la gráfica de barras: por hora
/// si es un día, por día si es una semana, por semana si es un mes, por mes
/// si es un año (y lo mismo según la duración de un rango personalizado).
/// `transacciones` puede traer movimientos fuera del rango (ej. porque
/// también se pidió el periodo anterior para comparar) — cada tramo filtra
/// los suyos por fecha.
List<BucketFlujo> calcularBuckets(
  SeleccionPeriodo seleccion,
  List<Transaccion> transacciones,
) {
  final rango = seleccion.rango;
  final tramos = <(DateTime, DateTime, String)>[];
  switch (seleccion.tramo) {
    case Tramo.horas:
      for (var h = 0; h < 24; h += 4) {
        final inicio = DateTime(
          rango.desde.year,
          rango.desde.month,
          rango.desde.day,
          h,
        );
        tramos.add((inicio, inicio.add(const Duration(hours: 4)), '${h}h'));
      }
    case Tramo.dia:
      var dia = rango.desde;
      while (dia.isBefore(rango.hasta)) {
        final fin = DateTime(dia.year, dia.month, dia.day + 1);
        tramos.add((
          dia,
          fin,
          // Una semana normal lleva el nombre del día; un rango, el número.
          seleccion.esPersonalizado
              ? '${dia.day}'
              : _diasSemanaEs[dia.weekday - 1],
        ));
        dia = fin;
      }
    case Tramo.semana:
      var inicio = rango.desde;
      var numero = 1;
      while (inicio.isBefore(rango.hasta)) {
        final siete = DateTime(inicio.year, inicio.month, inicio.day + 7);
        final fin = siete.isBefore(rango.hasta) ? siete : rango.hasta;
        tramos.add((inicio, fin, 'Sem $numero'));
        inicio = fin;
        numero++;
      }
    case Tramo.mes:
      var inicio = DateTime(rango.desde.year, rango.desde.month);
      while (inicio.isBefore(rango.hasta)) {
        final fin = DateTime(inicio.year, inicio.month + 1);
        tramos.add((
          inicio.isBefore(rango.desde) ? rango.desde : inicio,
          fin.isAfter(rango.hasta) ? rango.hasta : fin,
          _mesesAbreviados[inicio.month - 1],
        ));
        inicio = fin;
      }
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
