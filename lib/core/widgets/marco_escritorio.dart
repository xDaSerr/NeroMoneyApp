import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/assistant/data/controlador_asistente.dart';
import '../../features/assistant/providers/controlador_asistente_provider.dart';
import '../../features/assistant/widgets/panel_voz_asistente.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/onboarding/data/perfil_usuario.dart';
import '../../features/onboarding/providers/perfil_providers.dart';
import '../../features/profile/data/saludo_usuario.dart';
import 'boton_hablar.dart';
import 'escucha_segura.dart';
import 'menu_lateral.dart';
import 'observador_modales.dart';

/// Marco de la app en escritorio: menú lateral a la izquierda, el botón
/// "Hablar con…" abajo a la derecha, y el contenido (el Navigator de toda la
/// app) en medio. Vive fuera del router (lo coloca main.dart) para que
/// también las pantallas que no son pestaña, como Reportes, se vean dentro
/// del mismo marco.
///
/// Al cambiar de sección, la nueva "sale" del botón de esa sección: el
/// contenido se revela desde el rectángulo del botón hasta llenar su área
/// (pedido explícito del usuario; se probó con un contorno de luz alrededor
/// y pidió quitarlo). El chat sale del botón "Hablar con…".
///
/// OJO: la estructura de widgets alrededor de [child] es la misma con el
/// marco activo o no — si el Navigator cambiara de lugar en el árbol se
/// reconstruiría y perdería su estado (ver main.dart → _distribuir).
class MarcoEscritorio extends ConsumerStatefulWidget {
  const MarcoEscritorio({
    super.key,
    required this.activo,
    required this.ruta,
    required this.onIr,
    required this.child,
  });

  /// false en teléfono, en el acceso y en el onboarding: entonces el marco
  /// no dibuja nada y [child] ocupa todo.
  final bool activo;
  final String ruta;
  final ValueChanged<String> onIr;
  final Widget child;

  @override
  ConsumerState<MarcoEscritorio> createState() => _MarcoEscritorioState();
}

class _MarcoEscritorioState extends ConsumerState<MarcoEscritorio>
    with SingleTickerProviderStateMixin {
  static const _duracion = Duration(milliseconds: 520);

  final _llaves = {for (final s in SeccionEscritorio.values) s: GlobalKey()};
  final _llaveMarco = GlobalKey();

  late final AnimationController _revelado = AnimationController(
    vsync: this,
    duration: _duracion,
    value: 1,
  );

  /// Rectángulo (en coordenadas del marco) del botón del que sale la
  /// sección que se está abriendo.
  Rect? _origen;

  @override
  void didUpdateWidget(MarcoEscritorio anterior) {
    super.didUpdateWidget(anterior);
    if (!widget.activo || !anterior.activo) return;
    final antes = SeccionEscritorio.deRuta(anterior.ruta);
    final ahora = SeccionEscritorio.deRuta(widget.ruta);
    // Solo entre secciones: abrir/cerrar un formulario (agregar movimiento,
    // editar perfil...) usa la transición normal de página.
    if (antes == null || ahora == null || antes == ahora) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final origen = _rectDe(_llaves[ahora]!);
    if (origen == null) return;
    _origen = origen;
    _revelado.forward(from: 0);
  }

  Rect? _rectDe(GlobalKey llave) {
    final caja = llave.currentContext?.findRenderObject() as RenderBox?;
    final marco = _llaveMarco.currentContext?.findRenderObject() as RenderBox?;
    if (caja == null || marco == null || !caja.hasSize) return null;
    return caja.localToGlobal(Offset.zero, ancestor: marco) & caja.size;
  }

  @override
  void dispose() {
    _revelado.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activo = widget.activo;
    final seccion = SeccionEscritorio.deRuta(widget.ruta);
    final anchoMenu = activo ? MenuLateral.ancho : 0.0;

    // Material: el menú y el botón viven fuera de las pantallas (y de sus
    // Scaffold), así que sin esto el texto no tendría estilo base (sale
    // subrayado en amarillo) ni habría dónde pintar los efectos de toque.
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        key: _llaveMarco,
        builder: (context, restricciones) {
          final contenido = Rect.fromLTWH(
            anchoMenu,
            0,
            restricciones.maxWidth - anchoMenu,
            restricciones.maxHeight,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: anchoMenu,
                    child: activo
                        ? _Menu(
                            activa: seccion,
                            llaves: _llaves,
                            onIr: (s) => widget.onIr(s.ruta),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedBuilder(
                          animation: _revelado,
                          child: widget.child,
                          builder: (context, hijo) {
                            final rect = _rectActual(contenido);
                            final t = _progreso;
                            return ClipPath(
                              clipper: _Recorte(
                                rect?.shift(-contenido.topLeft),
                                radio: rect == null ? 0 : 18 * (1 - t),
                              ),
                              child: Opacity(
                                opacity: rect == null ? 1 : 0.2 + 0.8 * t,
                                child: hijo,
                              ),
                            );
                          },
                        ),
                        if (activo)
                          _CapaAsistente(
                            seccion: seccion,
                            llaveBoton: _llaves[SeccionEscritorio.asistente]!,
                            onAbrirChat: () =>
                                widget.onIr(SeccionEscritorio.asistente.ruta),
                          )
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  double get _progreso => Curves.easeOutCubic.transform(_revelado.value);

  /// null cuando no hay animación en curso (el contenido se ve completo).
  Rect? _rectActual(Rect contenido) {
    if (_origen == null || _revelado.value >= 1) return null;
    return Rect.lerp(_origen, contenido, _progreso);
  }
}

/// El menú con el saludo del usuario (lo único del marco que necesita el
/// perfil y la sesión).
class _Menu extends ConsumerWidget {
  const _Menu({required this.activa, required this.llaves, required this.onIr});

  final SeccionEscritorio? activa;
  final Map<SeccionEscritorio, GlobalKey> llaves;
  final ValueChanged<SeccionEscritorio> onIr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilProvider).value;
    final saludo = datosDeSaludo(
      ref.watch(authStateChangesProvider).value,
      perfil?.apodo,
    );
    return MenuLateral(
      activa: activa,
      onIr: onIr,
      llaves: llaves,
      nombreUsuario: saludo.nombre,
      inicialUsuario: saludo.inicial,
      nombreAsistente: perfil?.nombreAsistente ?? 'Lucy',
    );
  }
}

/// El botón "Hablar con…" y el panel con la transcripción/respuesta. Solo en
/// las secciones: en el chat no (ahí está su propio micrófono) ni en los
/// formularios de un solo paso.
class _CapaAsistente extends ConsumerWidget {
  const _CapaAsistente({
    required this.seccion,
    required this.llaveBoton,
    required this.onAbrirChat,
  });

  final SeccionEscritorio? seccion;
  final GlobalKey llaveBoton;
  final VoidCallback onAbrirChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilProvider).value;
    final asistente = ref.watch(controladorAsistenteProvider);
    final enChat = seccion == SeccionEscritorio.asistente;
    final conBoton = seccion != null && !enChat;

    return EscuchaSegura(
      escuchar: Listenable.merge([asistente, observadorModales.abiertos]),
      builder: (context) => Stack(
        children: [
          // Se esconde mientras haya un panel o diálogo abierto: dibujado
          // encima del navegador, tapaba sus botones (ver ObservadorModales).
          if (conBoton && observadorModales.abiertos.value == 0)
            Positioned(
              right: 28,
              bottom: 24,
              child: BotonHablar(
                key: llaveBoton,
                nombreAsistente: (perfil?.asistenteNombrado ?? true)
                    ? perfil?.nombreAsistente
                    : null,
                avatarBase64: perfil?.avatarAsistenteBase64,
                coloresAnillo: _coloresAnillo(perfil),
                escuchando: asistente.pulsado,
                enviando: asistente.enviando,
                onAbrirChat: onAbrirChat,
                onPrepararGesto: asistente.descartarAviso,
                onMantener: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  asistente.iniciar();
                },
                onSoltar: asistente.soltar,
                onCancelar: asistente.cancelar,
              ),
            )
          else
            // El botón sigue existiendo (invisible) para que el chat pueda
            // "salir" de él aunque esté oculto en ese momento.
            Positioned(
              right: 28,
              bottom: 24,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: SizedBox(key: llaveBoton, width: 320, height: 72),
                ),
              ),
            ),
          Positioned(
            right: 28,
            bottom: 112,
            width: 420,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (hijo, animacion) => FadeTransition(
                opacity: animacion,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animacion),
                  child: hijo,
                ),
              ),
              // En el chat solo los avisos que no tienen otro lugar donde
              // verse (mismo criterio que AppShell en teléfono).
              child:
                  asistente.mostrarPanel &&
                      (!enChat ||
                          asistente.estado == EstadoDictado.error ||
                          asistente.estado == EstadoDictado.sinVoz ||
                          asistente.estado == EstadoDictado.revision)
                  ? PanelVozAsistente(
                      key: const ValueKey('panel-visible'),
                      controlador: asistente,
                      nombre: perfil?.nombreAsistente ?? 'Lucy',
                    )
                  : const SizedBox.shrink(key: ValueKey('panel-oculto')),
            ),
          ),
        ],
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

class _Recorte extends CustomClipper<Path> {
  _Recorte(this.rect, {required this.radio});

  /// null = sin animación: se ve todo.
  final Rect? rect;
  final double radio;

  @override
  Path getClip(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        rect ?? Offset.zero & size,
        Radius.circular(radio),
      ),
    );

  @override
  bool shouldReclip(_Recorte viejo) =>
      viejo.rect != rect || viejo.radio != radio;
}
