import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/features/analisis/data/deteccion.dart';
import 'package:neromoney_app/features/transactions/data/transaccion.dart';

var _n = 0;
Transaccion _gasto(
  double monto,
  DateTime fecha, {
  String descripcion = '',
  String categoria = 'Otro',
  TipoTransaccion tipo = TipoTransaccion.gasto,
  String? transferencia,
}) => Transaccion(
  id: '${_n++}',
  monto: monto,
  tipo: tipo,
  categoria: categoria,
  cuentaId: 'c',
  fecha: fecha,
  descripcion: descripcion,
  transferenciaId: transferencia,
);

void main() {
  final ahora = DateTime(2026, 11, 13);

  test('detecta suscripciones mensuales aunque varíe el texto', () {
    final d = Deteccion.analizar([
      _gasto(219, DateTime(2026, 8, 5), descripcion: 'Netflix'),
      _gasto(219, DateTime(2026, 9, 5), descripcion: 'NETFLIX'),
      _gasto(229, DateTime(2026, 10, 5), descripcion: 'netflix '),
      _gasto(229, DateTime(2026, 11, 5), descripcion: 'Netflix'),
      // Gimnasio sin descripción: mismo monto y categoría cada mes.
      _gasto(650, DateTime(2026, 9, 1), categoria: 'Salud'),
      _gasto(650, DateTime(2026, 10, 1), categoria: 'Salud'),
      _gasto(650, DateTime(2026, 11, 1), categoria: 'Salud'),
    ], ahora);

    expect(d.recurrentes.map((r) => r.nombre), ['Salud', 'Netflix']);
    final netflix = d.recurrentes[1];
    expect(netflix.monto, 229);
    expect(netflix.veces, 4);
    expect(netflix.proximaFecha, DateTime(2026, 12, 5));
    expect(d.totalRecurrenteMensual, 879);
  });

  test('no confunde un gasto semanal, montos distintos o uno cancelado', () {
    final d = Deteccion.analizar([
      // Semanal: intervalos de 7 días.
      for (var i = 0; i < 8; i++)
        _gasto(
          80,
          DateTime(2026, 9, 1).add(Duration(days: 7 * i)),
          descripcion: 'Uber',
        ),
      // Mismo nombre, montos muy distintos.
      _gasto(300, DateTime(2026, 9, 10), descripcion: 'Amazon'),
      _gasto(1200, DateTime(2026, 10, 10), descripcion: 'Amazon'),
      // Mensual, pero el último cobro fue hace más de 45 días.
      _gasto(99, DateTime(2026, 7, 20), descripcion: 'Spotify'),
      _gasto(99, DateTime(2026, 8, 20), descripcion: 'Spotify'),
      // Transferencias no cuentan.
      _gasto(500, DateTime(2026, 10, 1), transferencia: 't'),
      _gasto(500, DateTime(2026, 11, 1), transferencia: 't2'),
    ], ahora);
    expect(d.recurrentes, isEmpty);
  });

  test('gastos hormiga: chicos, frecuentes y de los últimos 30 días', () {
    final d = Deteccion.analizar([
      // Gastos "grandes" que dan contexto.
      for (var i = 0; i < 6; i++)
        _gasto(1500, DateTime(2026, 10, 1 + i * 5), descripcion: 'Súper'),
      // Café: 6 veces este mes, montos chicos que varían.
      for (var i = 0; i < 6; i++)
        _gasto(
          55.0 + i,
          DateTime(2026, 10, 20 + i * 4),
          descripcion: 'Café',
          categoria: 'Alimentación',
        ),
      // Café viejo (fuera de los 30 días): no suma.
      _gasto(60, DateTime(2026, 9, 1), descripcion: 'Café'),
      // Solo 2 veces: no es hormiga.
      _gasto(40, DateTime(2026, 11, 1), descripcion: 'Chicles'),
      _gasto(40, DateTime(2026, 11, 2), descripcion: 'Chicles'),
    ], ahora);

    expect(d.hormiga, hasLength(1));
    final cafe = d.hormiga.first;
    expect(cafe.nombre, 'Café');
    expect(cafe.veces, 6);
    expect(cafe.total, 55 * 6 + 15);
    expect(cafe.alAnio, closeTo(cafe.total * 365 / 30, 0.01));
  });

  test('con pocos movimientos no inventa gastos hormiga', () {
    final d = Deteccion.analizar([
      for (var i = 0; i < 5; i++)
        _gasto(30, DateTime(2026, 11, 1 + i), descripcion: 'Café'),
    ], ahora);
    expect(d.hormiga, isEmpty);
    expect(d.vacia, isTrue);
  });

  test('un cobro del 31 de enero se espera el 28 de febrero', () {
    final d = Deteccion.analizar([
      _gasto(100, DateTime(2026, 12, 31), descripcion: 'Renta'),
      _gasto(100, DateTime(2027, 1, 31), descripcion: 'Renta'),
    ], DateTime(2027, 2, 5));
    expect(d.recurrentes.single.proximaFecha, DateTime(2027, 2, 28));
  });

  test('rango: los últimos 4 meses completos', () {
    expect(Deteccion.rango(ahora), (DateTime(2026, 8), DateTime(2026, 12)));
  });
}
