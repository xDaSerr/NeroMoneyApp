import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/features/accounts/data/cuenta.dart';
import 'package:neromoney_app/features/transactions/data/resumen_gastos.dart';
import 'package:neromoney_app/features/transactions/data/transaccion.dart';
import 'package:neromoney_app/features/transactions/data/transacciones_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late TransaccionesRepository repo;
  final fecha = DateTime(2026, 9, 7);

  Future<void> cuenta(String id, TipoCuenta tipo, double saldo) => db
      .doc('usuarios/prueba/cuentas/$id')
      .set(
        Cuenta(
          id: id,
          nombre: id,
          tipo: tipo,
          saldoActual: saldo,
        ).toFirestore(),
      );
  Future<double> saldo(String id) async =>
      ((await db.doc('usuarios/prueba/cuentas/$id').get())
                  .data()!['saldoActual']
              as num)
          .toDouble();
  Future<List<Transaccion>> movimientos() async =>
      (await db.collection('usuarios/prueba/transacciones').get()).docs
          .map(Transaccion.fromFirestore)
          .toList();
  Future<void> transferir({
    String id = 'operacion',
    String origen = 'debito',
    String destino = 'efectivo',
    double monto = 125.75,
  }) async => repo.registrarTransferencia(
    id: id,
    cuentaOrigenId: origen,
    cuentaDestinoId: destino,
    monto: monto,
    fecha: fecha,
  );

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = TransaccionesRepository(db, 'prueba');
    await cuenta('debito', TipoCuenta.debito, 500);
    await cuenta('efectivo', TipoCuenta.efectivo, 200);
    await cuenta('credito', TipoCuenta.credito, 1000);
  });

  test(
    'débito a efectivo conserva patrimonio y enlaza los dos movimientos',
    () async {
      await transferir();
      expect(await saldo('debito'), 374.25);
      expect(await saldo('efectivo'), 325.75);
      final lista = await movimientos();
      expect(lista, hasLength(2));
      expect(lista.every((t) => t.esTransferencia), isTrue);
      final salida = lista.singleWhere((t) => t.tipo == TipoTransaccion.gasto);
      final entrada = lista.singleWhere(
        (t) => t.tipo == TipoTransaccion.ingreso,
      );
      expect(salida.transferenciaId, entrada.transferenciaId);
      expect(salida.cuentaContraparteId, entrada.cuentaId);
      expect(entrada.cuentaContraparteId, salida.cuentaId);
      expect(salida.efectoEnSaldo + entrada.efectoEnSaldo, 0);
      expect(
        (await repo.observarPorCuenta('efectivo').first).single.id,
        entrada.id,
      );
    },
  );

  test(
    'efectivo a débito permite transferir todo el saldo sin negativos',
    () async {
      await transferir(origen: 'efectivo', destino: 'debito', monto: 200);
      expect(await saldo('efectivo'), 0);
      expect(await saldo('debito'), 700);
    },
  );

  test('un centavo conserva precisión en ambos saldos', () async {
    await cuenta('debito', TipoCuenta.debito, 0.30);
    await transferir(monto: 0.29);
    expect(await saldo('debito'), 0.01);
    expect(await saldo('efectivo'), 200.29);
  });

  test(
    'saldo insuficiente no altera ninguna cuenta ni crea movimientos',
    () async {
      await expectLater(
        transferir(monto: 500.01),
        throwsA(isA<SaldoInsuficienteException>()),
      );
      expect(await saldo('debito'), 500);
      expect(await saldo('efectivo'), 200);
      expect(await movimientos(), isEmpty);
    },
  );

  test(
    'rechaza misma cuenta, importes inválidos y fracciones de centavo',
    () async {
      await expectLater(transferir(destino: 'debito'), throwsArgumentError);
      for (final monto in [
        0.0,
        -1.0,
        double.nan,
        double.infinity,
        0.001,
        0.000000001,
        12.345,
      ]) {
        await expectLater(transferir(monto: monto), throwsArgumentError);
      }
      expect(await saldo('debito'), 500);
      expect(await movimientos(), isEmpty);
    },
  );

  test('no permite crédito ni cuentas borradas o de otro usuario', () async {
    await db.doc('usuarios/otro/cuentas/ajena').set({'saldoActual': 99});
    for (final destino in ['credito', 'borrada', 'ajena']) {
      await expectLater(transferir(destino: destino), throwsStateError);
    }
    await expectLater(transferir(origen: 'credito'), throwsStateError);
    expect(await saldo('debito'), 500);
    expect(await movimientos(), isEmpty);
  });

  test(
    'reintentar el mismo ID no duplica; datos cambiados no se reaplican',
    () async {
      await transferir();
      await transferir();
      expect(await saldo('debito'), 374.25);
      expect(await movimientos(), hasLength(2));
      await expectLater(transferir(monto: 100), throwsStateError);
      expect(await saldo('debito'), 374.25);
    },
  );

  for (final tipo in TipoTransaccion.values) {
    test(
      'deshacer desde ${tipo.name} restaura ambas cuentas una sola vez',
      () async {
        await transferir();
        final lista = await movimientos();
        await repo.eliminarTransaccion(
          lista.singleWhere((t) => t.tipo == tipo),
        );
        expect(await saldo('debito'), 500);
        expect(await saldo('efectivo'), 200);
        expect(await movimientos(), isEmpty);
        // Simula otro dispositivo usando una copia vieja de la otra mitad.
        await repo.eliminarTransaccion(
          lista.singleWhere((t) => t.tipo != tipo),
        );
        expect(await saldo('debito'), 500);
        expect(await saldo('efectivo'), 200);
      },
    );
  }

  test('no deshace si el destino gastó el dinero o falta una cuenta', () async {
    await transferir();
    final salida = (await movimientos()).first;
    await cuenta('efectivo', TipoCuenta.efectivo, 10);
    await expectLater(repo.eliminarTransaccion(salida), throwsStateError);
    expect(await saldo('debito'), 374.25);
    expect(await saldo('efectivo'), 10);
    expect(await movimientos(), hasLength(2));
    await db.doc('usuarios/prueba/cuentas/efectivo').delete();
    await expectLater(repo.eliminarTransaccion(salida), throwsStateError);
    expect(await saldo('debito'), 374.25);
    expect(await movimientos(), hasLength(2));
  });

  test(
    'una mitad de transferencia en la ventana no altera gastos ni reembolsos',
    () async {
      await transferir();
      final salida = (await movimientos()).singleWhere(
        (t) => t.tipo == TipoTransaccion.gasto,
      );
      final resumen = ResumenGastos.calcular(
        [
          salida,
          Transaccion(
            id: 'gasto',
            monto: 80,
            tipo: TipoTransaccion.gasto,
            categoria: 'Comida',
            cuentaId: 'debito',
            fecha: fecha,
          ),
          Transaccion(
            id: 'reembolso',
            monto: 20,
            tipo: TipoTransaccion.ingreso,
            categoria: 'Comida',
            cuentaId: 'debito',
            fecha: fecha,
          ),
        ],
        desde: DateTime(2026, 9),
        hasta: DateTime(2026, 10),
      );
      expect(resumen.total, 60);
      expect(resumen.porCategoria, {'Comida': 60});
    },
  );
}
