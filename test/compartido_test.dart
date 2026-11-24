import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/features/compartido/data/grupo.dart';

GastoCompartido gasto(double monto, String pago, List<String> entre,
        {bool esPago = false}) =>
    GastoCompartido(
      id: '',
      monto: monto,
      descripcion: '',
      categoria: 'Otro',
      pagoUid: pago,
      entre: entre,
      fecha: DateTime(2026, 11, 23),
      esPago: esPago,
    );

void main() {
  test('pareja: quien pagó más recibe la diferencia', () {
    final b = BalanceGrupo.calcular([
      gasto(1000, 'ana', ['ana', 'luis']),
      gasto(400, 'luis', ['ana', 'luis']),
    ]);
    expect(b.neto['ana'], 300);
    expect(b.neto['luis'], -300);
    expect(b.deudas.single.de, 'luis');
    expect(b.deudas.single.para, 'ana');
    expect(b.deudas.single.monto, 300);
  });

  test('un pago deja a todos a mano', () {
    final b = BalanceGrupo.calcular([
      gasto(1000, 'ana', ['ana', 'luis']),
      gasto(500, 'luis', ['ana'], esPago: true),
    ]);
    expect(b.deudas, isEmpty);
  });

  test('tres personas: se salda con pocos pagos y los centavos cuadran', () {
    final b = BalanceGrupo.calcular([
      gasto(100, 'a', ['a', 'b', 'c']),
    ]);
    final total = b.deudas.fold<double>(0, (s, d) => s + d.monto);
    expect(b.deudas.length, 2);
    expect(total, closeTo(66.67, 0.011));
    expect(b.deudas.every((d) => d.para == 'a'), isTrue);
  });
}
