import 'transaccion.dart';

/// Gasto neto por categoría en un rango de fechas: gastos MENOS ingresos de
/// esa misma categoría — un reembolso cancela su gasto original en vez de
/// sumarse aparte o quedar sin efecto (ver "Gastos del mes" en Inicio y el
/// prompt de Lucy en functions/index.js, ambos se apoyan en esta misma
/// lógica para no tener el mismo cálculo — y el mismo tipo de bug— en dos
/// lugares distintos).
class ResumenGastos {
  const ResumenGastos({required this.total, required this.porCategoria});

  /// Suma de las categorías con gasto neto positivo (una categoría
  /// totalmente reembolsada no cuenta, ni con signo negativo).
  final double total;

  /// Solo categorías con neto > 0, ordenadas de mayor a menor.
  final Map<String, double> porCategoria;

  static ResumenGastos calcular(
    List<Transaccion> transacciones, {
    required DateTime desde,
    required DateTime hasta,
  }) {
    final enRango = transacciones.where(
      (t) => !t.fecha.isBefore(desde) && t.fecha.isBefore(hasta),
    );

    final netoPorCategoria = <String, double>{};
    for (final t in enRango) {
      final signo = t.tipo == TipoTransaccion.gasto ? 1.0 : -1.0;
      netoPorCategoria.update(t.categoria, (v) => v + signo * t.monto, ifAbsent: () => signo * t.monto);
    }

    final entradas = netoPorCategoria.entries.where((e) => e.value > 0.01).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entradas.fold<double>(0, (acc, e) => acc + e.value);

    return ResumenGastos(
      total: total,
      porCategoria: {for (final e in entradas) e.key: e.value},
    );
  }
}
