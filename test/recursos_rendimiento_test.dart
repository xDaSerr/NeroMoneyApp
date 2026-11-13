import 'dart:async';
import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/core/widgets/asistente_avatar.dart';
import 'package:neromoney_app/features/assistant/data/controlador_asistente.dart';
import 'package:neromoney_app/features/transactions/data/transaccion.dart';
import 'package:neromoney_app/features/transactions/data/transacciones_repository.dart';
import 'package:neromoney_app/features/transactions/providers/transacciones_providers.dart';

import 'support/escenario_rendimiento.dart' show MotorSimulado;

class RepositorioObservable extends TransaccionesRepository {
  RepositorioObservable() : super(FakeFirebaseFirestore(), 'prueba');
  int activos = 0;
  Stream<List<Transaccion>> _stream() {
    late StreamController<List<Transaccion>> stream;
    stream = StreamController(
      onListen: () {
        activos++;
        stream.add([]);
      },
      onCancel: () {
        activos--;
      },
    );
    return stream.stream;
  }

  @override
  Stream<List<Transaccion>> observarPorCuenta(String cuentaId) => _stream();
  @override
  Stream<List<Transaccion>> observarPorRango(DateTime desde, DateTime hasta) =>
      _stream();
}

void main() {
  test('cerrar detalles y cambiar periodos libera sus suscripciones', () async {
    final repo = RepositorioObservable();
    final container = ProviderContainer(
      overrides: [transaccionesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    for (var i = 0; i < 6; i++) {
      final cuenta = container.listen(
        transaccionesPorCuentaProvider('cuenta-$i'),
        (_, _) {},
      );
      final periodo = container.listen(
        transaccionesPorRangoProvider((
          DateTime(2026, i + 1),
          DateTime(2026, i + 2),
        )),
        (_, _) {},
      );
      await container.pump();
      expect(repo.activos, 2);
      cuenta.close();
      periodo.close();
      await container.pump();
      expect(repo.activos, 0);
    }
  });

  test(
    'volumen conserva actualización visual y descarta callbacks tras cancelar',
    () async {
      final motor = MotorSimulado();
      final asistente = ControladorAsistente(
        motor: motor,
        enviar: (_, _) async => null,
        completar: (_, _) async => null,
        hablar: (_) async {},
        callar: () async {},
      );
      addTearDown(asistente.dispose);
      await asistente.iniciar();
      var muestras = 0;
      asistente.nivelAudio.addListener(() => muestras++);
      motor.volumen(.5);
      motor.volumen(.5);
      motor.volumen(double.nan);
      expect(muestras, 1);
      expect(asistente.nivel, .5);
      asistente.cancelar();
      expect(asistente.nivel, 0);
      motor.volumen(.8);
      expect(asistente.nivel, 0);
      expect(muestras, 2);
    },
  );

  testWidgets(
    'barra y burbujas comparten foto sin acumular una copia por avatar',
    (tester) async {
      // PNG transparente de 1 px; solo se verifica la identidad de su caché.
      const foto =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==';
      await tester.pumpWidget(
        const MaterialApp(
          home: Row(
            children: [
              AsistenteAvatar(avatarBase64: foto),
              AsistenteAvatar(avatarBase64: foto, size: 43),
            ],
          ),
        ),
      );
      final imagenes = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(identical(imagenes[0].image, imagenes[1].image), isTrue);
      expect((imagenes.first.image as MemoryImage).bytes, base64Decode(foto));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
