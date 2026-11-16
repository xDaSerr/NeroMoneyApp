import '../../transactions/data/transaccion.dart';

/// Un gasto que se repite cada mes por un monto parecido (Netflix, el
/// gimnasio, la renta).
class CargoRecurrente {
  const CargoRecurrente({
    required this.nombre,
    required this.categoria,
    required this.monto,
    required this.veces,
    required this.ultimaFecha,
    required this.proximaFecha,
  });

  final String nombre;
  final String categoria;

  /// El último monto cobrado.
  final double monto;
  final int veces;
  final DateTime ultimaFecha;
  final DateTime proximaFecha;
}

/// Gastos chicos que se repiten mucho (el café, los antojos, el
/// estacionamiento) y que juntos suman bastante.
class GastoHormiga {
  const GastoHormiga({
    required this.nombre,
    required this.categoria,
    required this.veces,
    required this.total,
  });

  final String nombre;
  final String categoria;
  final int veces;

  /// Lo gastado en los últimos 30 días.
  final double total;

  double get promedio => total / veces;
  double get alAnio => total * 365 / Deteccion.diasHormiga;
}

/// Lo que se repite en los gastos del usuario. Sin IA: reglas simples
/// sobre los movimientos, para que siempre dé lo mismo y no cueste nada.
class Deteccion {
  const Deteccion({required this.recurrentes, required this.hormiga});

  final List<CargoRecurrente> recurrentes;
  final List<GastoHormiga> hormiga;

  double get totalRecurrenteMensual =>
      recurrentes.fold(0, (a, c) => a + c.monto);
  double get totalHormiga => hormiga.fold(0, (a, h) => a + h.total);
  double get hormigaAlAnio => hormiga.fold(0, (a, h) => a + h.alAnio);
  bool get vacia => recurrentes.isEmpty && hormiga.isEmpty;

  /// Meses de historia que se revisan para encontrar cargos recurrentes.
  static const mesesHistoria = 4;
  static const diasHormiga = 30;

  /// Rango [desde, hasta) que hay que pedir para analizar en [ahora].
  static (DateTime, DateTime) rango(DateTime ahora) => (
    DateTime(ahora.year, ahora.month - mesesHistoria + 1),
    DateTime(ahora.year, ahora.month + 1),
  );

  static Deteccion analizar(List<Transaccion> transacciones, DateTime ahora) {
    final gastos =
        transacciones
            .where(
              (t) =>
                  t.tipo == TipoTransaccion.gasto &&
                  !t.esTransferencia &&
                  t.categoria != 'Ajuste' &&
                  t.montoPrincipal > 0 &&
                  !t.fecha.isAfter(ahora),
            )
            .toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final recurrentes = _recurrentes(gastos, ahora);
    final claves = {for (final r in recurrentes) _normalizar(r.nombre)};
    final hormiga = _hormiga(gastos, ahora, excluir: claves);
    return Deteccion(recurrentes: recurrentes, hormiga: hormiga);
  }

  // --- Cargos recurrentes ---

  static List<CargoRecurrente> _recurrentes(
    List<Transaccion> gastos,
    DateTime ahora,
  ) {
    // Sin descripción no hay nombre que comparar: se agrupan por categoría
    // y monto exacto (dos cobros idénticos cada mes también son un cargo
    // fijo).
    final grupos = <String, List<Transaccion>>{};
    for (final t in gastos) {
      final clave = _normalizar(t.descripcion).isEmpty
          ? '#${t.categoria}#${t.montoPrincipal.toStringAsFixed(2)}'
          : _normalizar(t.descripcion);
      grupos.putIfAbsent(clave, () => []).add(t);
    }

    final resultado = <CargoRecurrente>[];
    for (final lista in grupos.values) {
      if (lista.length < 2) continue;
      // Montos parecidos: todos dentro de ±15% de la mediana.
      final mediana = _mediana(lista.map((t) => t.montoPrincipal).toList());
      if (lista.any(
        (t) => (t.montoPrincipal - mediana).abs() > mediana * 0.15,
      )) {
        continue;
      }
      // Cada mes: el tiempo típico entre cobros va de 25 a 35 días. Un café
      // diario o semanal queda fuera aunque cueste siempre lo mismo.
      final intervalos = [
        for (var i = 1; i < lista.length; i++)
          lista[i].fecha.difference(lista[i - 1].fecha).inDays,
      ];
      final tipico = _mediana(intervalos.map((d) => d.toDouble()).toList());
      if (tipico < 25 || tipico > 35) continue;
      // Si ya pasó mes y medio sin cobro, probablemente se canceló.
      final ultimo = lista.last;
      if (ahora.difference(ultimo.fecha).inDays > 45) continue;

      resultado.add(
        CargoRecurrente(
          nombre: _nombre(ultimo),
          categoria: ultimo.categoria,
          monto: ultimo.montoPrincipal,
          veces: lista.length,
          ultimaFecha: ultimo.fecha,
          // Mismo día del mes siguiente (el 5 de cada mes, no "31 días
          // después").
          proximaFecha: _mesSiguiente(ultimo.fecha),
        ),
      );
    }
    return resultado..sort((a, b) => b.monto.compareTo(a.monto));
  }

  // --- Gastos hormiga ---

  static List<GastoHormiga> _hormiga(
    List<Transaccion> gastos,
    DateTime ahora, {
    required Set<String> excluir,
  }) {
    // "Chico" depende de cada quien (y de su moneda): hasta 1.25 veces su
    // gasto típico (la mediana) de los últimos meses. El margen evita que
    // un café de $60 quede fuera porque el anterior costó $59. Con muy
    // pocos datos no se puede saber.
    if (gastos.length < 10) return const [];
    final umbral =
        _mediana(gastos.map((t) => t.montoPrincipal).toList()) * 1.25;

    final desde = ahora.subtract(const Duration(days: diasHormiga));
    final grupos = <String, List<Transaccion>>{};
    for (final t in gastos) {
      if (t.fecha.isBefore(desde) || t.montoPrincipal > umbral) continue;
      final clave = _normalizar(t.descripcion).isEmpty
          ? '#${t.categoria}'
          : _normalizar(t.descripcion);
      if (excluir.contains(clave)) continue;
      grupos.putIfAbsent(clave, () => []).add(t);
    }

    return [
      for (final lista in grupos.values)
        if (lista.length >= 4)
          GastoHormiga(
            nombre: _normalizar(lista.last.descripcion).isEmpty
                ? '${lista.last.categoria} (varios)'
                : _nombre(lista.last),
            categoria: lista.last.categoria,
            veces: lista.length,
            total: lista.fold(0, (a, t) => a + t.montoPrincipal),
          ),
    ]..sort((a, b) => b.total.compareTo(a.total));
  }

  // --- Utilidades ---

  /// "Netflix ", "NETFLIX" y "netflix 12" se consideran lo mismo.
  static String _normalizar(String texto) => texto
      .toLowerCase()
      .replaceAll(RegExp(r'[0-9#*.,:;\-_/]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _nombre(Transaccion t) {
    final d = t.descripcion.trim();
    if (d.isEmpty) return t.categoria;
    return '${d[0].toUpperCase()}${d.substring(1)}';
  }

  /// El mismo día del mes siguiente; si no existe (31 de enero → febrero),
  /// el último día de ese mes.
  static DateTime _mesSiguiente(DateTime f) {
    final ultimoDia = DateTime(f.year, f.month + 2, 0).day;
    return DateTime(f.year, f.month + 1, f.day.clamp(1, ultimoDia));
  }

  static double _mediana(List<double> valores) {
    final v = [...valores]..sort();
    final m = v.length ~/ 2;
    return v.length.isOdd ? v[m] : (v[m - 1] + v[m]) / 2;
  }
}
