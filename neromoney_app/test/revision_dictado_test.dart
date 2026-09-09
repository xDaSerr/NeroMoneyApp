import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/features/accounts/providers/cuentas_providers.dart';
import 'package:neromoney_app/features/assistant/data/controlador_asistente.dart';
import 'package:neromoney_app/features/assistant/data/mensaje_chat.dart';
import 'package:neromoney_app/features/assistant/widgets/panel_voz_asistente.dart';

class MotorConConfianza implements MotorDictado {
  late void Function(String, bool, [double?]) resultado;
  @override
  Future<bool> preparar() async => true;
  @override
  Future<void> escuchar({
    required void Function(String, bool, [double?]) resultado,
    required void Function(double) nivel,
    required void Function(FalloDictado) error,
  }) async {
    this.resultado = resultado;
  }

  @override
  Future<void> detener() async {}
  @override
  Future<void> cancelar() async {}
}

void main() {
  late MotorConConfianza motor;
  late ControladorAsistente controlador;
  late List<(String, bool)> envios;
  var revisionSiempre = false;
  void crear() {
    motor = MotorConConfianza();
    envios = [];
    controlador = ControladorAsistente(
      motor: motor,
      revisarAntesDeEnviar: () => revisionSiempre,
      esperaFinal: const Duration(milliseconds: 1),
      enviar: (texto, voz) async {
        envios.add((texto, voz));
        return MensajeChat(
          id: '1',
          autor: AutorMensaje.asistente,
          contenido: 'Listo',
          fecha: DateTime(2026),
        );
      },
      completar: (_, _) async => null,
      hablar: (_) async {},
      callar: () async {},
    );
  }

  setUp(() {
    revisionSiempre = false;
    crear();
  });
  tearDown(() => controlador.dispose());

  test('dictado claro sigue enviándose al soltar; parciales tardíos no cambian el final', () async {
    await controlador.iniciar();
    motor.resultado('Gasté 20 en efectivo', true, 0.9);
    motor.resultado('Gasté 200', false);
    expect(envios, isEmpty);
    await controlador.soltar();
    expect(envios, [('Gasté 20 en efectivo', true)]);
  });
  for (final confianza in <double?>[0.2, null, -1, double.nan]) {
    test('confianza $confianza exige revisar antes de registrar', () async {
      await controlador.iniciar();
      motor.resultado('Gasté 200', true, confianza);
      await controlador.soltar();
      expect(controlador.revisando, isTrue);
      expect(controlador.ocupado, isFalse);
      expect(envios, isEmpty);
      await controlador.confirmarDictado('Gasté 20 en efectivo');
      await controlador.confirmarDictado('Gasté 20 en efectivo');
      expect(envios, [('Gasté 20 en efectivo', true)]);
    });
  }
  test('transcripción provisional nunca se envía automáticamente', () async {
    await controlador.iniciar();
    motor.resultado('Gasté', false, 0.95);
    await controlador.soltar();
    expect(controlador.revisando, isTrue);
    expect(envios, isEmpty);
  });
  test('revisión siempre activa también detiene un dictado claro', () async {
    revisionSiempre = true;
    await controlador.iniciar();
    motor.resultado('Hola', true, 1);
    await controlador.soltar();
    expect(controlador.revisando, isTrue);
    expect(envios, isEmpty);
  });
  test(
    'cerrar la revisión descarta el dictado; el siguiente gesto funciona',
    () async {
      await controlador.iniciar();
      final anterior = motor.resultado;
      anterior('Ruido', true, 0.1);
      await controlador.soltar();
      controlador.ocultarPanel();
      await controlador.confirmarDictado('No enviar');
      await controlador.iniciar();
      anterior('Resultado viejo', true, 1);
      expect(controlador.transcripcion, isEmpty);
      motor.resultado('Hola', true, 1);
      await controlador.soltar();
      expect(envios, [('Hola', true)]);
    },
  );
  testWidgets('el panel permite corregir y enviar sin abrir el chat', (
    tester,
  ) async {
    controlador.dispose();
    crear();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cuentasProvider.overrideWith((ref) => Stream.value([]))],
        child: MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controlador,
              builder: (_, _) =>
                  PanelVozAsistente(controlador: controlador, nombre: 'Nero'),
            ),
          ),
        ),
      ),
    );
    await controlador.iniciar();
    motor.resultado('Gasté 200', true, 0.2);
    await controlador.soltar();
    await tester.pumpAndSettle();
    expect(find.text('Revisa lo que escuché'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Gasté 20 en efectivo');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(envios, [('Gasté 20 en efectivo', true)]);
    expect(tester.takeException(), isNull);
    // El panel de respuesta se oculta solo pasado un rato (ver
    // ControladorAsistente._duracionAutoOcultar) — hay que dejar pasar ese
    // tiempo simulado para no terminar la prueba con ese temporizador
    // todavía pendiente.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
  });
}
