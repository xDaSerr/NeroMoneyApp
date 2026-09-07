import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/barra_flotante.dart';
import '../../features/assistant/data/controlador_asistente.dart';
import '../../features/assistant/providers/controlador_asistente_provider.dart';
import '../../features/assistant/widgets/panel_voz_asistente.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/onboarding/data/perfil_usuario.dart';
import '../../features/onboarding/providers/perfil_providers.dart';
import '../../features/reminders/providers/recordatorios_sync_provider.dart';

/// Margen dentro del scroll para poder subir el último elemento por encima
/// de la barra y su avatar. También separa los controles fijos del chat.
/// El viewport debe llegar al fondo (SafeArea con bottom: false): reservar
/// este espacio fuera del scroll recorta el contenido y rompe la flotación.
double espacioParaBarraFlotante(BuildContext context) {
  // Con el teclado abierto, Scaffold ya reduce el cuerpo hasta su borde;
  // la navegación queda debajo del teclado y no necesita otro margen.
  if (MediaQuery.viewInsetsOf(context).bottom > 0) return 0;

  // extendBody sustituye padding.bottom por la altura de la navegación.
  // viewPadding conserva el espacio real del sistema y evita contar la
  // barra dos veces. El mínimo coincide con el SafeArea de BarraFlotante.
  final gestoInicio = MediaQuery.viewPaddingOf(context).bottom;
  final margenInferior = gestoInicio < 8 ? 8.0 : gestoInicio;
  return BarraFlotante.altura + margenInferior + 10;
}

/// Contenedor de las 5 pestañas principales. `navigationShell` viene de
/// go_router (StatefulShellRoute) y mantiene el estado/historial de
/// navegación de cada pestaña por separado — si entras a "Movimientos",
/// navegas a un detalle, y cambias a "Perfil" y regresas, "Movimientos"
/// sigue donde lo dejaste en vez de reiniciarse.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  ControladorAsistente? _asistente;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Una llamada, bloqueo o salida de la app cancela la captura sin enviar.
    if (state != AppLifecycleState.resumed) _asistente?.cancelar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Justo al cerrar sesión, o mientras un inicio de sesión con Google
    // todavía no termina, hay un instante en el que este shell sigue
    // montado pero ya no hay uid — controladorAsistenteProvider (y todo lo
    // que depende de la sesión) truena en ese instante ("usado sin sesión
    // activa"), y sin este freno se veía la pantalla roja de error de
    // Flutter por un parpadeo. El router redirige a login/onboarding un
    // frame después, así que aquí basta con no dibujar nada mientras tanto.
    if (ref.watch(currentUidProvider) == null) {
      return const SizedBox.shrink();
    }

    // Mantiene los recordatorios de gastos sincronizados con el perfil
    // mientras haya sesión (ver recordatorios_sync_provider.dart) — no
    // dibuja nada, solo necesita estar vivo.
    ref.watch(recordatoriosSyncProvider);

    final perfil = ref.watch(perfilProvider).value;
    final asistente = ref.watch(controladorAsistenteProvider);
    _asistente = asistente;
    final navigationShell = widget.navigationShell;

    return ListenableBuilder(
      listenable: asistente,
      builder: (context, _) => Scaffold(
        // Para que la píldora flote SOBRE el contenido de cada pestaña en
        // vez de dejar un hueco reservado (que se veía como "un cuadro"
        // detrás de ella, sin fundirse con el resto de la pantalla). Cada
        // pestaña deja su propio margen abajo — ver espacioParaBarraFlotante.
        extendBody: true,
        // Este Scaffold envuelve a las 5 pestañas, cada una con su propio
        // Scaffold interno (ej. el chat, con su campo de texto). Si este
        // Scaffold exterior TAMBIÉN se encoge para el teclado, se resta el
        // alto del teclado dos veces (una vez aquí, otra en el Scaffold
        // interno) y queda un hueco vacío entre la barra de texto y el
        // teclado — se vio justo en el chat al tocar el campo de escribir.
        // Solo la pestaña activa (la que de verdad tiene un campo de texto)
        // debe encogerse; este Scaffold nunca dibuja nada que lo necesite.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(child: navigationShell),
            if (asistente.mostrarPanel)
              Positioned(
                left: 16,
                right: 16,
                bottom:
                    MediaQuery.viewInsetsOf(context).bottom +
                    espacioParaBarraFlotante(context) +
                    8,
                child: PanelVozAsistente(
                  controlador: asistente,
                  nombre: perfil?.nombreAsistente ?? 'Lucy',
                ),
              ),
          ],
        ),
        bottomNavigationBar: BarraFlotante(
          pulsado: asistente.pulsado,
          ocupado: asistente.ocupado,
          enviando: asistente.enviando,
          nivel: asistente.nivel,
          nivelAudio: asistente.nivelAudio,
          onPrepararGesto: asistente.descartarAviso,
          onMantener: () {
            FocusManager.instance.primaryFocus?.unfocus();
            asistente.iniciar();
          },
          onSoltar: asistente.soltar,
          onCancelar: asistente.cancelar,
          indiceActual: navigationShell.currentIndex,
          onSeleccionar: (i) => navigationShell.goBranch(
            i,
            // Si ya estás en esa pestaña, regresa a su raíz en vez de apilar.
            initialLocation: i == navigationShell.currentIndex,
          ),
          avatarBase64: perfil?.avatarAsistenteBase64,
          coloresAnillo: _coloresAnillo(perfil),
          nombreAsistente: perfil?.nombreAsistente ?? 'Lucy',
        ),
      ),
    );
  }

  List<Color>? _coloresAnillo(PerfilUsuario? perfil) {
    final inicio = perfil?.colorAnilloInicio;
    final fin = perfil?.colorAnilloFin;
    if (inicio == null || fin == null) return null;
    return [Color(inicio), Color(fin)];
  }
}
