import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:neromoney_app/core/router/app_shell.dart';
import 'package:neromoney_app/features/accounts/providers/cuentas_providers.dart';
import 'package:neromoney_app/features/assistant/data/controlador_asistente.dart';
import 'package:neromoney_app/features/assistant/data/mensaje_chat.dart';
import 'package:neromoney_app/features/assistant/providers/controlador_asistente_provider.dart';
import 'package:neromoney_app/features/auth/providers/auth_providers.dart';
import 'package:neromoney_app/features/onboarding/providers/perfil_providers.dart';

class MotorPrueba implements MotorDictado {
  Completer<bool>? permiso;
  void Function(String, bool)? resultado;
  void Function(FalloDictado)? error;
  int escuchas = 0;
  int cancelaciones = 0;
  @override
  Future<bool> preparar() async => permiso == null ? true : permiso!.future;
  @override
  Future<void> escuchar({
    required void Function(String, bool, [double?]) resultado,
    required void Function(double) nivel,
    required void Function(FalloDictado) error,
  }) async {
    escuchas++;
    this.resultado = (texto, finalizado) => resultado(texto, finalizado, 0.95);
    this.error = error;
  }

  @override
  Future<void> detener() async {}
  @override
  Future<void> cancelar() async {
    cancelaciones++;
  }
}

void main() {
  late MotorPrueba motor;
  late ControladorAsistente controlador;
  late List<(String, bool)> envios;
  late List<String> voces;
  final respuesta = MensajeChat(
    id: 'respuesta',
    autor: AutorMensaje.asistente,
    contenido: 'Registrado',
    fecha: DateTime(2026),
    registrado: true,
  );

  void crearControlador({
    Duration esperaFinal = const Duration(milliseconds: 10),
  }) {
    motor = MotorPrueba();
    envios = [];
    voces = [];
    controlador = ControladorAsistente(
      motor: motor,
      enviar: (texto, voz) async {
        envios.add((texto, voz));
        return respuesta;
      },
      completar: (id, voz) async {
        envios.add((id, voz));
        return respuesta;
      },
      hablar: (texto) async {
        voces.add(texto);
      },
      callar: () async {},
      esperaFinal: esperaFinal,
      revisarAntesDeEnviar: () => false,
    );
  }

  setUp(crearControlador);
  tearDown(() => controlador.dispose());

  Future<GoRouter> montarBarra(WidgetTester tester, {int indice = 0}) async {
    final router = GoRouter(
      initialLocation: '/p$indice',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            for (var i = 0; i < 5; i++)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/p$i',
                    builder: (_, _) =>
                        const Scaffold(body: Text('Pestaña actual')),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('usuario-prueba'),
          controladorAsistenteProvider.overrideWithValue(controlador),
          perfilProvider.overrideWith((ref) => const Stream.empty()),
          cuentasProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('reintenta desde la barra con el aviso de silencio aún abierto', (
    tester,
  ) async {
    controlador.dispose();
    crearControlador();
    final router = await montarBarra(tester);
    final boton = find.byKey(const ValueKey('boton-asistente-global'));
    final primera = await tester.startGesture(tester.getCenter(boton));
    await tester.pump(const Duration(milliseconds: 600));
    expect(motor.escuchas, 1);
    motor.error!(const FalloDictado('Inténtalo de nuevo.', sinVoz: true));
    await primera.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No te escuché'), findsOneWidget);

    final segunda = await tester.startGesture(tester.getCenter(boton));
    await tester.pump(const Duration(milliseconds: 600));
    expect(motor.escuchas, 2);
    expect(controlador.pulsado, isTrue);
    expect(find.text('No te escuché'), findsNothing);
    expect(find.text('Te escucho · suelta para enviar'), findsOneWidget);
    expect(envios, isEmpty);
    await segunda.cancel();
    controlador.cancelar();
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  testWidgets(
    'conserva la segunda pulsación mientras finaliza el primer dictado',
    (tester) async {
      controlador.dispose();
      crearControlador(esperaFinal: const Duration(milliseconds: 1400));
      final router = await montarBarra(tester);
      final boton = find.byKey(const ValueKey('boton-asistente-global'));
      final primera = await tester.startGesture(tester.getCenter(boton));
      await tester.pump(const Duration(milliseconds: 600));
      expect(motor.escuchas, 1);
      await primera.up();
      await tester.pump();
      expect(controlador.estado, EstadoDictado.finalizando);

      final segunda = await tester.startGesture(tester.getCenter(boton));
      await tester.pump(const Duration(milliseconds: 600));
      expect(motor.escuchas, 1);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      expect(motor.escuchas, 2);
      expect(controlador.pulsado, isTrue);
      expect(controlador.estado, EstadoDictado.escuchando);
      expect(envios, isEmpty);
      await segunda.cancel();
      controlador.cancelar();
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );

  testWidgets('soltar el reintento pendiente no deja una escucha diferida', (
    tester,
  ) async {
    controlador.dispose();
    crearControlador(esperaFinal: const Duration(milliseconds: 1400));
    final router = await montarBarra(tester);
    final boton = find.byKey(const ValueKey('boton-asistente-global'));
    final primera = await tester.startGesture(tester.getCenter(boton));
    await tester.pump(const Duration(milliseconds: 600));
    await primera.up();
    await tester.pump();
    final segunda = await tester.startGesture(tester.getCenter(boton));
    await tester.pump(const Duration(milliseconds: 600));
    await segunda.up();
    await tester.pump(const Duration(seconds: 2));
    expect(motor.escuchas, 1);
    expect(controlador.pulsado, isFalse);
    expect(envios, isEmpty);
    controlador.cancelar();
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  testWidgets('en chat el avatar no activa ni interrumpe su micrófono', (
    tester,
  ) async {
    controlador.dispose();
    crearControlador();
    final router = await montarBarra(tester, indice: 2);
    final boton = find.byKey(const ValueKey('boton-asistente-global'));
    final gesto = await tester.startGesture(tester.getCenter(boton));
    await tester.pump(const Duration(milliseconds: 600));
    expect(motor.escuchas, 0);
    // El botón del chat sí puede iniciar el controlador compartido.
    await controlador.iniciar();
    await tester.pump(const Duration(milliseconds: 300));
    final transform = tester.widget<Transform>(
      find.descendant(of: boton, matching: find.byType(Transform)).first,
    );
    expect(transform.transform.getMaxScaleOnAxis(), 1);
    await gesto.up();
    await tester.pump();
    expect(controlador.pulsado, isTrue);
    controlador.cancelar();
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  testWidgets('el aviso de silencio desaparece a los tres segundos', (
    tester,
  ) async {
    controlador.dispose();
    crearControlador();
    await controlador.iniciar();
    motor.error!(const FalloDictado('Sin voz.', sinVoz: true));
    expect(controlador.ocupado, isFalse);
    expect(controlador.mostrarPanel, isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(controlador.mostrarPanel, isFalse);
    expect(controlador.estado, EstadoDictado.inactivo);
    expect(envios, isEmpty);
  });

  testWidgets('un temporizador viejo no oculta una nueva escucha', (
    tester,
  ) async {
    controlador.dispose();
    crearControlador();
    await controlador.iniciar();
    motor.error!(const FalloDictado('Sin voz.', sinVoz: true));
    await controlador.iniciar();
    await tester.pump(const Duration(seconds: 4));
    expect(controlador.estado, EstadoDictado.escuchando);
    expect(controlador.mostrarPanel, isTrue);
    controlador.cancelar();
  });

  testWidgets('los errores de permisos no desaparecen automáticamente', (
    tester,
  ) async {
    controlador.dispose();
    crearControlador();
    await controlador.iniciar();
    motor.error!(const FalloDictado('Permiso de micrófono requerido.'));
    await tester.pump(const Duration(seconds: 4));
    expect(controlador.mostrarPanel, isTrue);
    expect(controlador.estado, EstadoDictado.error);
    expect(controlador.ocupado, isFalse);
  });

  test(
    'el resultado final no registra hasta soltar; duplicados envían una vez',
    () async {
      await controlador.iniciar();
      motor.resultado!('Gasté 20 en efectivo', true);
      motor.resultado!('Gasté 20 en efectivo', true);
      expect(envios, isEmpty);
      expect(controlador.pulsado, isTrue);
      await Future.wait([controlador.soltar(), controlador.soltar()]);
      motor.resultado!('Gasté 20 en efectivo', true);
      expect(envios, [('Gasté 20 en efectivo', true)]);
      expect(controlador.respuesta?.registrado, isTrue);
      expect(controlador.pulsado, isFalse);
      expect(voces, ['Registrado']);
    },
  );

  test('soltar durante permisos no inicia una escucha después', () async {
    motor.permiso = Completer<bool>();
    final inicio = controlador.iniciar();
    await Future<void>.delayed(Duration.zero);
    await controlador.soltar();
    motor.permiso!.complete(true);
    await inicio;
    expect(motor.escuchas, 0);
    expect(envios, isEmpty);
    expect(controlador.ocupado, isFalse);
  });

  test('espera la última transcripción que llega al detener', () async {
    await controlador.iniciar();
    motor.resultado!('Gasté', false);
    final envio = controlador.soltar();
    motor.resultado!('Gasté 50 en comida', true);
    await envio;
    expect(envios.single.$1, 'Gasté 50 en comida');
  });

  test('cancelación ignora resultados tardíos y no envía', () async {
    await controlador.iniciar();
    final callbackViejo = motor.resultado!;
    controlador.cancelar();
    callbackViejo('Gasté 50', true);
    await controlador.soltar();
    expect(envios, isEmpty);
    await controlador.iniciar();
    callbackViejo('Texto de la sesión anterior', true);
    expect(controlador.transcripcion, isEmpty);
  });

  test('silencio no crea mensajes ni transacciones', () async {
    await controlador.iniciar();
    await controlador.soltar();
    expect(envios, isEmpty);
    expect(controlador.estado, EstadoDictado.sinVoz);
    expect(controlador.respuesta, isNull);
  });

  test(
    'un error nativo restaura la barra e impide enviar la captura',
    () async {
      await controlador.iniciar();
      motor.resultado!('Gasté 20', false);
      motor.error!(const FalloDictado('Micrófono no disponible'));
      await controlador.soltar();
      expect(controlador.pulsado, isFalse);
      expect(controlador.error, 'Micrófono no disponible');
      expect(envios, isEmpty);
    },
  );

  test(
    'bloquea envíos desde el chat mientras el micrófono está activo',
    () async {
      await controlador.iniciar();
      await controlador.enviarTexto('Otro gasto');
      await controlador.elegirCuenta('cuenta');
      expect(envios, isEmpty);
    },
  );

  test(
    'texto queda silencioso y los chips de voz conservan respuesta hablada',
    () async {
      await controlador.enviarTexto('Hola');
      expect(envios.single.$2, isFalse);
      expect(voces, isEmpty);
      await controlador.iniciar();
      motor.resultado!('Gasté 20', true);
      await controlador.soltar();
      await controlador.elegirCuenta('efectivo');
      expect(envios.last, ('efectivo', true));
      expect(voces.length, 2);
    },
  );
}
