import '../../../core/utils/fecha_es.dart';
import '../../transactions/data/resumen_gastos.dart';
import '../../transactions/data/transaccion.dart';
import 'periodo_reporte.dart';

/// Una categoría en dos periodos.
class ComparacionCategoria {
  const ComparacionCategoria(this.categoria, this.actual, this.anterior);

  final String categoria;
  final double actual;
  final double anterior;

  /// Cambio en proporción (0.25 = +25%). null si antes no había gasto.
  double? get cambio => anterior <= 0 ? null : (actual - anterior) / anterior;
}

/// Este periodo contra el anterior (Plus).
class Comparacion {
  const Comparacion({
    required this.totalActual,
    required this.totalAnterior,
    required this.categorias,
    required this.etiquetaAnterior,
    required this.parcial,
  });

  final double totalActual;
  final double totalAnterior;
  final List<ComparacionCategoria> categorias;
  final String etiquetaAnterior;

  /// El periodo va en curso y se compara con el anterior hasta el mismo
  /// punto (no medio mes contra un mes completo).
  final bool parcial;

  double? get cambio =>
      totalAnterior <= 0 ? null : (totalActual - totalAnterior) / totalAnterior;

  /// Rango [desde, hasta) del periodo anterior a comparar.
  static RangoPeriodo rangoAnterior(
    SeleccionPeriodo seleccion, [
    DateTime? ahora,
  ]) {
    final actual = seleccion.rango;
    final anterior = seleccion.previa.rango;
    if (!actual.esActual) return anterior;
    final transcurrido = (ahora ?? DateTime.now()).difference(actual.desde);
    final hasta = anterior.desde.add(transcurrido);
    return RangoPeriodo(
      desde: anterior.desde,
      hasta: hasta.isAfter(anterior.hasta) ? anterior.hasta : hasta,
      etiqueta: anterior.etiqueta,
      esActual: false,
    );
  }

  static Comparacion calcular(
    List<Transaccion> transacciones,
    RangoPeriodo actual,
    RangoPeriodo anterior,
  ) {
    final a = ResumenGastos.calcular(
      transacciones,
      desde: actual.desde,
      hasta: actual.hasta,
    );
    final b = ResumenGastos.calcular(
      transacciones,
      desde: anterior.desde,
      hasta: anterior.hasta,
    );
    final nombres = {...a.porCategoria.keys, ...b.porCategoria.keys};
    final categorias = [
      for (final n in nombres)
        ComparacionCategoria(n, a.porCategoria[n] ?? 0, b.porCategoria[n] ?? 0),
    ]..sort((x, y) => y.actual.compareTo(x.actual));
    return Comparacion(
      totalActual: a.total,
      totalAnterior: b.total,
      categorias: categorias,
      etiquetaAnterior: anterior.etiqueta,
      parcial: actual.esActual,
    );
  }
}

/// Rango de los últimos 12 meses (incluido el actual).
(DateTime, DateTime) rangoDoceMeses([DateTime? ahora]) {
  final hoy = ahora ?? DateTime.now();
  return (
    DateTime(hoy.year, hoy.month - 11),
    DateTime(hoy.year, hoy.month + 1),
  );
}

/// Gasto neto e ingreso de cada uno de los últimos 12 meses (Plus).
List<BucketFlujo> tendenciaDoceMeses(
  List<Transaccion> transacciones, [
  DateTime? ahora,
]) {
  final hoy = ahora ?? DateTime.now();
  return [
    for (var i = 11; i >= 0; i--)
      () {
        final desde = DateTime(hoy.year, hoy.month - i);
        final hasta = DateTime(desde.year, desde.month + 1);
        return (
          etiqueta: mesCapitalizado(desde.month).substring(0, 3),
          ingreso: totalPeriodo(
            transacciones,
            TipoTransaccion.ingreso,
            desde: desde,
            hasta: hasta,
          ),
          gasto: ResumenGastos.calcular(
            transacciones,
            desde: desde,
            hasta: hasta,
          ).total,
        );
      }(),
  ];
}

/// "Tu 2026" (Pro): lo que va del año y cómo cerraría a este ritmo.
class ResumenAnio {
  const ResumenAnio({
    required this.anio,
    required this.gasto,
    required this.ingreso,
    required this.mesesTranscurridos,
    required this.mesesActivos,
    required this.mesMasCaro,
    required this.gastoMesMasCaro,
    required this.categoriaPrincipal,
    required this.gastoCategoriaPrincipal,
  });

  final int anio;
  final double gasto;
  final double ingreso;

  /// Meses del año que ya pasaron, con el actual en fracción (13 de
  /// noviembre ≈ 10.4).
  final double mesesTranscurridos;

  /// Meses desde el primer movimiento del año (mínimo 1): si empezaste a
  /// usar la app en noviembre, tu ritmo se mide desde noviembre, no como
  /// si hubieras gastado desde enero.
  final double mesesActivos;
  final int? mesMasCaro;
  final double gastoMesMasCaro;
  final String? categoriaPrincipal;
  final double gastoCategoriaPrincipal;

  double get ahorro => ingreso - gasto;
  double get gastoPromedioMensual => gasto / mesesActivos;
  double get _mesesRestantes => 12 - mesesTranscurridos;

  /// Lo que va del año más el ritmo mensual por los meses que faltan.
  double get proyeccionGasto => gasto + gastoPromedioMensual * _mesesRestantes;
  double get proyeccionIngreso =>
      ingreso + ingreso / mesesActivos * _mesesRestantes;
  double get proyeccionAhorro => proyeccionIngreso - proyeccionGasto;
  bool get vacio => gasto == 0 && ingreso == 0;

  static ResumenAnio calcular(List<Transaccion> transacciones, DateTime ahora) {
    final desde = DateTime(ahora.year);
    final hasta = DateTime(ahora.year + 1);
    final gastos = ResumenGastos.calcular(
      transacciones,
      desde: desde,
      hasta: hasta,
    );
    int? mesMasCaro;
    var maximo = 0.0;
    for (var m = 1; m <= ahora.month; m++) {
      final total = ResumenGastos.calcular(
        transacciones,
        desde: DateTime(ahora.year, m),
        hasta: DateTime(ahora.year, m + 1),
      ).total;
      if (total > maximo) {
        maximo = total;
        mesMasCaro = m;
      }
    }
    final diasDelMes = DateTime(ahora.year, ahora.month + 1, 0).day;
    final principal = gastos.porCategoria.entries.firstOrNull;
    final transcurridos = (ahora.month - 1) + ahora.day / diasDelMes;
    final delAnio = transacciones.where(
      (t) =>
          !t.esTransferencia &&
          !t.fecha.isBefore(desde) &&
          !t.fecha.isAfter(ahora),
    );
    final primero = delAnio.isEmpty
        ? desde
        : delAnio.map((t) => t.fecha).reduce((a, b) => a.isBefore(b) ? a : b);
    // Mismos "meses del calendario" que [transcurridos], desde el mes del
    // primer movimiento.
    final activos = (transcurridos - (primero.month - 1)).clamp(
      1.0,
      transcurridos < 1 ? 1.0 : transcurridos,
    );
    return ResumenAnio(
      anio: ahora.year,
      gasto: gastos.total,
      ingreso: totalPeriodo(
        transacciones,
        TipoTransaccion.ingreso,
        desde: desde,
        hasta: hasta,
      ),
      mesesTranscurridos: transcurridos,
      mesesActivos: activos,
      mesMasCaro: mesMasCaro,
      gastoMesMasCaro: maximo,
      categoriaPrincipal: principal?.key,
      gastoCategoriaPrincipal: principal?.value ?? 0,
    );
  }
}
