import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/features/libreta/data/apunte_libreta.dart';
import 'package:neromoney_app/features/transactions/data/transaccion.dart';

void main() {
  final hoy = DateTime(2026, 11, 23);

  ApunteLibreta apunte({
    DireccionPrestamo direccion = DireccionPrestamo.yoPresto,
    double monto = 1000,
    List<double> pagos = const [],
    DateTime? promesa,
  }) => ApunteLibreta(
    id: 'a',
    direccion: direccion,
    persona: 'Ana',
    monto: monto,
    fecha: DateTime(2026, 11, 1),
    fechaPromesa: promesa,
    pagos: [for (final p in pagos) PagoLibreta(monto: p, fecha: hoy)],
  );

  test('pagos en partes: falta lo que no se ha pagado', () {
    final a = apunte(pagos: [300, 200]);
    expect(a.pagado, 500);
    expect(a.pendiente, 500);
    expect(a.liquidado, isFalse);
    expect(apunte(pagos: [1000]).liquidado, isTrue);
  });

  test('días para la fecha prometida, negativo si ya pasó', () {
    expect(apunte(promesa: DateTime(2026, 11, 25)).diasParaPromesa(hoy), 2);
    expect(apunte(promesa: DateTime(2026, 11, 20)).diasParaPromesa(hoy), -3);
    expect(
      apunte(promesa: DateTime(2026, 11, 20), pagos: [1000])
          .diasParaPromesa(hoy),
      isNull,
    );
  });

  test('resumen: te deben, debes y vencidos', () {
    final r = ResumenLibreta.calcular([
      apunte(pagos: [400], promesa: DateTime(2026, 11, 20)),
      apunte(direccion: DireccionPrestamo.mePrestan, monto: 250),
      apunte(monto: 90, pagos: [90]),
    ], hoy);
    expect(r.meDeben, 600);
    expect(r.debo, 250);
    expect(r.vencidos, 1);
  });

  test('los movimientos de la libreta no cuentan como gasto', () {
    final t = Transaccion(
      id: '',
      monto: 500,
      tipo: TipoTransaccion.gasto,
      categoria: 'Préstamo',
      cuentaId: 'c',
      fecha: hoy,
      libretaId: 'a',
    );
    expect(t.esMovimientoInterno, isTrue);
    expect(t.esTransferencia, isFalse);
  });
}
