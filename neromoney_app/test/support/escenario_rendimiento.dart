import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neromoney_app/core/router/app_shell.dart';
import 'package:neromoney_app/core/theme/app_theme.dart';
import 'package:neromoney_app/features/accounts/accounts_screen.dart';
import 'package:neromoney_app/features/accounts/data/cuenta.dart';
import 'package:neromoney_app/features/accounts/providers/cuentas_providers.dart';
import 'package:neromoney_app/features/accounts/widgets/cuenta_tile.dart';
import 'package:neromoney_app/features/assistant/assistant_chat_screen.dart';
import 'package:neromoney_app/features/assistant/data/controlador_asistente.dart';
import 'package:neromoney_app/features/assistant/data/mensaje_chat.dart';
import 'package:neromoney_app/features/assistant/providers/asistente_providers.dart';
import 'package:neromoney_app/features/assistant/providers/controlador_asistente_provider.dart';
import 'package:neromoney_app/features/auth/providers/auth_providers.dart';
import 'package:neromoney_app/features/onboarding/data/perfil_usuario.dart';
import 'package:neromoney_app/features/onboarding/providers/perfil_providers.dart';
import 'package:neromoney_app/features/reminders/providers/recordatorios_sync_provider.dart';

/// Datos en memoria: no inicia sesión, no graba audio ni escribe en Firebase.
class MotorSimulado implements MotorDictado {
  late void Function(double) volumen;
  @override
  Future<bool> preparar() async => true;
  @override
  Future<void> escuchar({
    required void Function(String, bool, [double?]) resultado,
    required void Function(double) nivel,
    required void Function(FalloDictado) error,
  }) async => volumen = nivel;
  @override
  Future<void> detener() async {}
  @override
  Future<void> cancelar() async {}
}

void registrarPruebaRendimiento({
  void Function(Map<String, Object>)? onReporte,
}) {
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets('cuentas, navegación y dictado con carga reproducible', (
    tester,
  ) async {
    final motor = MotorSimulado();
    final asistente = ControladorAsistente(
      motor: motor,
      enviar: (_, _) async => throw StateError('No enviar durante la prueba'),
      completar: (_, _) async =>
          throw StateError('No registrar durante la prueba'),
      hablar: (_) async {},
      callar: () async {},
    );
    final cuentas = List.generate(
      30,
      (i) => Cuenta(
        id: 'cuenta-$i',
        nombre: 'Cuenta de prueba $i',
        tipo: TipoCuenta.values[i % 3],
        saldoActual: 1000 + i.toDouble(),
        limiteCredito: i % 3 == 2 ? 5000 : null,
      ),
    );
    final mensajes = List.generate(
      80,
      (i) => MensajeChat(
        id: 'mensaje-$i',
        autor: i.isEven ? AutorMensaje.usuario : AutorMensaje.asistente,
        contenido:
            'Mensaje de prueba $i para revisar el desplazamiento del historial.',
        fecha: DateTime(2026, 9, 7, 12, i),
      ),
    );
    final router = GoRouter(
      initialLocation: '/accounts',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => AppShell(navigationShell: shell),
          branches: [
            for (final ruta in [
              '/home',
              '/movements',
              '/assistant',
              '/accounts',
              '/profile',
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: ruta,
                    builder: (_, _) => switch (ruta) {
                      '/accounts' => const AccountsScreen(),
                      '/assistant' => const AssistantChatScreen(),
                      _ => const Scaffold(
                        body: Center(child: Text('Prueba de navegación')),
                      ),
                    },
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
          currentUidProvider.overrideWithValue('prueba-local'),
          cuentasProvider.overrideWith((ref) => Stream.value(cuentas)),
          perfilProvider.overrideWith(
            (ref) => Stream.value(PerfilUsuario.vacio),
          ),
          mensajesChatProvider.overrideWith((ref) => Stream.value(mensajes)),
          borradorPendienteProvider.overrideWith((ref) => Stream.value(null)),
          recordatoriosSyncProvider.overrideWith((ref) {}),
          controladorAsistenteProvider.overrideWithValue(asistente),
        ],
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final tarjetasIniciales = find.byType(CuentaTile).evaluate().length;
    final scrollCuentas = find
        .descendant(
          of: find.byType(AccountsScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    for (var i = 0; i < 4; i++) {
      await tester.fling(scrollCuentas, const Offset(0, -700), 1800);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.tap(find.byKey(const ValueKey('boton-asistente-global')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Tras cargar el historial, leer mensajes anteriores mientras se dicta.
    final scrollChat = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(AssistantChatScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scrollChat.position.jumpTo(scrollChat.position.maxScrollExtent * .4);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await asistente.iniciar();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    scrollChat.position.jumpTo(scrollChat.position.maxScrollExtent * .4);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final antes = scrollChat.position.pixels;
    var notificaciones = 0;
    void contar() => notificaciones++;
    asistente.addListener(contar);
    for (var i = 0; i < 120; i++) {
      motor.volumen((i % 20) / 20);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final desplazamiento = scrollChat.position.pixels - antes;
    asistente.removeListener(contar);
    asistente.cancelar();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // También ejercitar la elevación global fuera del chat.
    await tester.tap(find.byKey(const ValueKey('destino-3')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await asistente.iniciar();
    for (var i = 0; i < 60; i++) {
      motor.volumen((i % 20) / 20);
      await tester.pump(const Duration(milliseconds: 16));
    }
    asistente.cancelar();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final reporte = <String, Object>{
      'cuentas_totales': cuentas.length,
      'tarjetas_montadas_al_abrir': tarjetasIniciales,
      'muestras_volumen_chat': 120,
      'notificaciones_generales_por_volumen': notificaciones,
      'desplazamiento_involuntario_chat_px': desplazamiento,
    };
    onReporte?.call(reporte);
    debugPrint('RENDIMIENTO: ${jsonEncode(reporte)}');
    expect(tarjetasIniciales, greaterThan(0));
    expect(tarjetasIniciales, lessThan(cuentas.length));
    expect(notificaciones, 0, reason: 'El volumen solo debe repintar el halo');
    expect(
      desplazamiento,
      closeTo(0, .01),
      reason: 'Dictar no debe mover el historial',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    asistente.dispose();
  });
}
