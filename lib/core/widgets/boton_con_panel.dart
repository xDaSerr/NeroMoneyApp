import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Un botón que al tocarlo se transforma en un panel (y al cerrar el panel,
/// regresa a ser el botón), como en el video de referencia que mandó el
/// usuario: el botón se estira con un pequeño rebote hasta el tamaño del
/// panel, y el contenido aparece desenfocado y se enfoca al llegar.
///
/// En pantallas anchas el panel queda a la derecha, de alto completo; en
/// teléfono ocupa casi toda la pantalla.
class BotonConPanel extends StatefulWidget {
  const BotonConPanel({
    super.key,
    required this.boton,
    required this.panel,
    this.colorBoton,
    this.radioBoton = 16,
  });

  /// El botón visible. Recibe `abrir` para conectarlo a su onTap.
  final Widget Function(BuildContext context, VoidCallback abrir) boton;

  /// El contenido del panel. Recibe `cerrar` (botón ×, "Cancelar" o al
  /// guardar).
  final Widget Function(BuildContext context, VoidCallback cerrar) panel;

  /// El color del botón: la forma que se estira parte de él y se funde con
  /// el fondo del panel.
  final Color? colorBoton;

  /// Radio de las esquinas del botón (un círculo de 56 = 28).
  final double radioBoton;

  @override
  State<BotonConPanel> createState() => _BotonConPanelState();
}

class _BotonConPanelState extends State<BotonConPanel> {
  final _llave = GlobalKey();
  bool _abierto = false;

  Future<void> _abrir() async {
    if (_abierto) return;
    // En el navegador raíz: así el panel cubre toda el área de contenido y
    // MarcoEscritorio sabe que está abierto (ver ObservadorModales).
    final navegador = Navigator.of(context, rootNavigator: true);
    final caja = _llave.currentContext?.findRenderObject() as RenderBox?;
    final capa = navegador.overlay?.context.findRenderObject() as RenderBox?;
    if (caja == null || capa == null) return;
    final origen = caja.localToGlobal(Offset.zero, ancestor: capa) & caja.size;
    final sinMovimiento = MediaQuery.disableAnimationsOf(context);

    setState(() => _abierto = true);
    await navegador.push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierLabel: 'Cerrar',
        barrierColor: Colors.black54,
        transitionDuration: sinMovimiento
            ? Duration.zero
            : const Duration(milliseconds: 460),
        reverseTransitionDuration: sinMovimiento
            ? Duration.zero
            : const Duration(milliseconds: 320),
        pageBuilder: (context, animacion, _) => _PanelTransformado(
          animacion: animacion,
          origen: origen,
          colorBoton: widget.colorBoton ?? AppColors.acento,
          radioBoton: widget.radioBoton,
          contenido: (context) =>
              widget.panel(context, () => Navigator.of(context).maybePop()),
        ),
      ),
    );
    // El botón vuelve a verse cuando el panel ya terminó de encogerse.
    if (mounted) setState(() => _abierto = false);
  }

  @override
  Widget build(BuildContext context) {
    // Mientras el panel está abierto, el botón real se oculta: lo que se ve
    // es la forma que salió de él.
    return Opacity(
      opacity: _abierto ? 0 : 1,
      child: KeyedSubtree(key: _llave, child: widget.boton(context, _abrir)),
    );
  }
}

class _PanelTransformado extends StatelessWidget {
  const _PanelTransformado({
    required this.animacion,
    required this.origen,
    required this.colorBoton,
    required this.radioBoton,
    required this.contenido,
  });

  final Animation<double> animacion;
  final Rect origen;
  final Color colorBoton;
  final double radioBoton;
  final WidgetBuilder contenido;

  /// Abre con un poco de rebote (se pasa del tamaño final y regresa), como
  /// el botón "elástico" del video; cierra sin rebote, más rápido.
  static const _curvaAbrir = Cubic(0.3, 1.25, 0.5, 1);
  static const _curvaCerrar = Curves.easeInCubic;

  Rect _destino(Size area, EdgeInsets seguro) {
    if (area.width >= 720) {
      const ancho = 460.0;
      return Rect.fromLTRB(
        area.width - ancho - 16,
        16 + seguro.top,
        area.width - 16,
        area.height - 16 - seguro.bottom,
      );
    }
    return Rect.fromLTRB(
      10,
      10 + seguro.top,
      area.width - 10,
      area.height - 10 - seguro.bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final curva = CurvedAnimation(
      parent: animacion,
      curve: _curvaAbrir,
      reverseCurve: _curvaCerrar,
    );
    // El contenido aparece en la segunda mitad del recorrido.
    final aparicion = CurvedAnimation(
      parent: animacion,
      curve: const Interval(0.35, 1, curve: Curves.easeOut),
      reverseCurve: const Interval(0.5, 1, curve: Curves.easeIn),
    );

    return LayoutBuilder(
      builder: (context, restricciones) {
        final destino = _destino(restricciones.biggest, mq.padding);
        // El contenido se ancla del lado del que viene el botón, para que
        // "salga" de él.
        final ancla = Alignment(
          ((origen.center.dx - destino.left) / destino.width * 2 - 1).clamp(
            -1,
            1,
          ),
          ((origen.center.dy - destino.top) / destino.height * 2 - 1).clamp(
            -1,
            1,
          ),
        );
        return AnimatedBuilder(
          animation: animacion,
          builder: (context, _) {
            final t = curva.value;
            final rect = Rect.lerp(origen, destino, t)!;
            final avance = t.clamp(0.0, 1.0);
            final visible = aparicion.value;
            final radio = radioBoton + (28 - radioBoton) * avance;
            final fondo = Color.lerp(
              colorBoton,
              AppColors.surface1,
              (avance * 1.8).clamp(0.0, 1.0),
            )!;
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fondo,
                      borderRadius: BorderRadius.circular(radio),
                      border: Border.all(
                        color: AppColors.glassStrokeHighlight.withValues(
                          alpha: avance,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45 * avance),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radio),
                      child: OverflowBox(
                        alignment: ancla,
                        minWidth: destino.width,
                        maxWidth: destino.width,
                        minHeight: destino.height,
                        maxHeight: destino.height,
                        child: Opacity(
                          opacity: visible,
                          child: ImageFiltered(
                            enabled: visible < 0.98,
                            imageFilter: ImageFilter.blur(
                              sigmaX: (1 - visible) * 10,
                              sigmaY: (1 - visible) * 10,
                            ),
                            // Material: los campos de texto lo necesitan y
                            // aquí no hay Scaffold.
                            child: Material(
                              type: MaterialType.transparency,
                              child: Builder(builder: contenido),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
