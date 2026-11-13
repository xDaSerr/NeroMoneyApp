import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:neromoney_app/features/accounts/data/cuenta.dart';
import 'package:neromoney_app/features/accounts/providers/cuentas_providers.dart';
import 'package:neromoney_app/features/transactions/data/transacciones_repository.dart';
import 'package:neromoney_app/features/transactions/providers/transacciones_providers.dart';
import 'package:neromoney_app/features/transactions/transfer_screen.dart';

class RepositorioSinConfirmacion extends TransaccionesRepository {
  RepositorioSinConfirmacion(super.db, super.uid);
  int intentos = 0;

  @override
  Future<void> registrarTransferencia({
    required String id,
    required String cuentaOrigenId,
    required String cuentaDestinoId,
    required double monto,
    required DateTime fecha,
    String nota = '',
  }) async {
    await super.registrarTransferencia(
      id: id,
      cuentaOrigenId: cuentaOrigenId,
      cuentaDestinoId: cuentaDestinoId,
      monto: monto,
      fecha: fecha,
      nota: nota,
    );
    if (++intentos == 1) {
      throw Exception('Confirmación perdida después de guardar');
    }
  }
}

void main() {
  const cuentas = [
    Cuenta(
      id: 'debito',
      nombre: 'Débito',
      tipo: TipoCuenta.debito,
      saldoActual: 500,
    ),
    Cuenta(
      id: 'efectivo',
      nombre: 'Billetera',
      tipo: TipoCuenta.efectivo,
      saldoActual: 200,
    ),
    Cuenta(
      id: 'credito',
      nombre: 'Crédito excluido',
      tipo: TipoCuenta.credito,
      saldoActual: 1000,
    ),
  ];

  for (final perderConfirmacion in [false, true]) {
    testWidgets(
      'formulario registra sin duplicar, confirmación perdida: $perderConfirmacion',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = FakeFirebaseFirestore();
        for (final c in cuentas) {
          await db.doc('usuarios/prueba/cuentas/${c.id}').set(c.toFirestore());
        }
        final repo = perderConfirmacion
            ? RepositorioSinConfirmacion(db, 'prueba')
            : TransaccionesRepository(db, 'prueba');
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('Inicio de prueba')),
            ),
            GoRoute(
              path: '/transfer',
              builder: (_, _) => const TransferScreen(),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cuentasProvider.overrideWith(
                (ref) => db
                    .collection('usuarios/prueba/cuentas')
                    .snapshots()
                    .map(
                      (snap) => snap.docs.map(Cuenta.fromFirestore).toList(),
                    ),
              ),
              transaccionesRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        router.push('/transfer');
        await tester.pumpAndSettle();

        final selectores = find.byType(DropdownButtonFormField<String>);
        await tester.tap(selectores.first);
        await tester.pumpAndSettle();
        expect(find.textContaining('Crédito excluido'), findsNothing);
        await tester.tap(find.text('Débito · Débito').last);
        await tester.pumpAndSettle();
        await tester.tap(selectores.last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Billetera · Efectivo').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '500.01');
        await tester.ensureVisible(find.text('Registrar transferencia'));
        await tester.tap(find.text('Registrar transferencia'));
        await tester.pumpAndSettle();
        expect(
          find.text('Saldo insuficiente en la cuenta de origen.'),
          findsOneWidget,
        );
        expect(
          (await db.collection('usuarios/prueba/transacciones').get()).docs,
          isEmpty,
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          perderConfirmacion ? '500' : '125,75',
        );
        await tester.pumpAndSettle();
        expect(
          find.text(perderConfirmacion ? r'$0.00' : r'$374.25'),
          findsOneWidget,
        );
        expect(
          find.text(perderConfirmacion ? r'$700.00' : r'$325.75'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Registrar transferencia'));
        await tester.tap(find.text('Registrar transferencia'));
        await tester.pumpAndSettle();
        if (perderConfirmacion) {
          expect(
            (await db.doc('usuarios/prueba/cuentas/debito').get())
                .data()!['saldoActual'],
            0,
          );
          expect(
            tester
                .widget<TextFormField>(find.byType(TextFormField).first)
                .enabled,
            isFalse,
          );
          await tester.ensureVisible(find.text('Reintentar confirmación'));
          await tester.tap(find.text('Reintentar confirmación'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Inicio de prueba'), findsOneWidget);
        expect(
          (await db.collection('usuarios/prueba/transacciones').get()).docs,
          hasLength(2),
        );
        expect(
          (await db.doc('usuarios/prueba/cuentas/debito').get())
              .data()!['saldoActual'],
          perderConfirmacion ? 0 : 374.25,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      },
    );
  }

  testWidgets(
    'una cuenta válida y una de crédito muestran el estado sin cuentas suficientes',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cuentasProvider.overrideWith(
              (ref) => Stream.value([cuentas.first, cuentas.last]),
            ),
          ],
          child: const MaterialApp(home: TransferScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Necesitas dos cuentas'), findsOneWidget);
      expect(find.text('Registrar transferencia'), findsNothing);
    },
  );
}
