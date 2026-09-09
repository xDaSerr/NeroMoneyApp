import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neromoney_app/core/theme/app_theme.dart';
import 'package:neromoney_app/core/widgets/barra_flotante.dart';
import 'package:neromoney_app/features/accounts/providers/cuentas_providers.dart';
import 'package:neromoney_app/features/assistant/assistant_chat_screen.dart';
import 'package:neromoney_app/features/assistant/data/controlador_asistente.dart';
import 'package:neromoney_app/features/assistant/data/mensaje_chat.dart';
import 'package:neromoney_app/features/assistant/providers/asistente_providers.dart';
import 'package:neromoney_app/features/assistant/providers/controlador_asistente_provider.dart';
import 'package:neromoney_app/features/assistant/widgets/burbuja_mensaje.dart';
import 'package:neromoney_app/features/onboarding/data/perfil_usuario.dart';
import 'package:neromoney_app/features/onboarding/providers/perfil_providers.dart';

import 'support/escenario_rendimiento.dart' show MotorSimulado;

void main() {
  testWidgets(
    'el chat pasa detrás del dock y deja visible el último mensaje con teclado y texto multilínea',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 850);
      addTearDown(tester.view.reset);
      final asistente = ControladorAsistente(
        motor: MotorSimulado(),
        enviar: (_, _) async => throw StateError('No enviar'),
        completar: (_, _) async => throw StateError('No registrar'),
        hablar: (_) async {},
        callar: () async {},
      );
      final mensajes = List.generate(
        30,
        (i) => MensajeChat(
          id: '$i',
          autor: AutorMensaje.asistente,
          contenido:
              'Mensaje ficticio $i para comprobar la flotación del chat.',
          fecha: DateTime(2026, 9, 8, 12, i),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            controladorAsistenteProvider.overrideWithValue(asistente),
            mensajesChatProvider.overrideWith((ref) => Stream.value(mensajes)),
            borradorPendienteProvider.overrideWith((ref) => Stream.value(null)),
            cuentasProvider.overrideWith((ref) => Stream.value([])),
            perfilProvider.overrideWith(
              (ref) => Stream.value(PerfilUsuario.vacio),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              extendBody: true,
              resizeToAvoidBottomInset: false,
              body: const AssistantChatScreen(),
              bottomNavigationBar: BarraFlotante(
                indiceActual: 2,
                onSeleccionar: (_) {},
                avatarBase64: null,
                coloresAnillo: null,
                nombreAsistente: 'Lucy',
                pulsado: false,
                ocupado: false,
                enviando: false,
                nivel: 0,
                onMantener: () {},
                onSoltar: () {},
                onCancelar: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lista = find.byType(ListView);
      final campo = find.byType(TextField);
      final controller = tester.widget<ListView>(lista).controller!;
      Future<void> comprobarUltimoVisible() async {
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final ultimo = find.byWidgetPredicate(
          (w) => w is BurbujaMensaje && w.mensaje.id == '29',
        );
        expect(
          tester.getBottomLeft(ultimo).dy,
          lessThan(tester.getTopLeft(campo).dy),
        );
        expect(tester.takeException(), isNull);
      }

      expect(
        tester.getBottomLeft(lista).dy,
        850,
        reason: 'El historial debe llegar detrás de la navegación',
      );
      await comprobarUltimoVisible();
      controller.jumpTo(controller.position.maxScrollExtent * .5);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(lista).dy,
        greaterThan(tester.getBottomLeft(campo).dy),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(campo).dy,
        closeTo(550 - 12, 1),
        reason: 'Solo un margen de 12 sobre el teclado',
      );
      await comprobarUltimoVisible();
      final altoInicial = tester.getSize(campo).height;
      await tester.enterText(
        campo,
        'Una línea\nOtra línea\nTercera línea\nCuarta línea',
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(campo).height, greaterThan(altoInicial));
      await comprobarUltimoVisible();
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      await comprobarUltimoVisible();
      await tester.pumpWidget(const SizedBox.shrink());
      asistente.dispose();
    },
  );
}
