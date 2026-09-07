import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'anillo_asistente.dart';

/// En reposo, la foto cabe dentro de la píldora recta. Al dictar solo las curvas centrales se deforman;
/// los extremos, la base y los destinos conservan sus coordenadas.
class BarraFlotante extends StatefulWidget {
  const BarraFlotante({
    super.key,
    required this.indiceActual,
    required this.onSeleccionar,
    required this.avatarBase64,
    required this.coloresAnillo,
    required this.nombreAsistente,
    required this.pulsado,
    required this.ocupado,
    required this.enviando,
    required this.nivel,
    this.nivelAudio,
    required this.onMantener,
    required this.onSoltar,
    required this.onCancelar,
    this.onPrepararGesto,
  });

  static const altura = 106.0;
  final int indiceActual;
  final ValueChanged<int> onSeleccionar;
  final String? avatarBase64;
  final List<Color>? coloresAnillo;
  final String nombreAsistente;
  final bool pulsado, ocupado, enviando;
  final double nivel;
  final ValueListenable<double>? nivelAudio;
  final VoidCallback onMantener, onSoltar, onCancelar;
  final VoidCallback? onPrepararGesto;

  @override
  State<BarraFlotante> createState() => _BarraFlotanteState();
}

class _BarraFlotanteState extends State<BarraFlotante>
    with WidgetsBindingObserver {
  bool _manteniendo = false;
  bool _esperando = false;
  bool get _dictadoHabilitado => widget.indiceActual != 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _manteniendo = false;
      _esperando = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(BarraFlotante oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dictadoHabilitado) {
      _manteniendo = false;
      _esperando = false;
      return;
    }
    // Si la segunda pulsación llegó mientras terminaba la primera,
    // conservarla. No requiere soltar y pulsar por tercera vez cuando
    // aparezca el aviso. La captura solo empieza si el dedo sigue abajo.
    if (_esperando && _manteniendo && !widget.ocupado) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _dictadoHabilitado &&
            _esperando &&
            _manteniendo &&
            !widget.ocupado) {
          _iniciarDictado();
        }
      });
    }
  }

  void _iniciarDictado() {
    _esperando = false;
    widget.onPrepararGesto?.call();
    HapticFeedback.lightImpact();
    widget.onMantener();
  }

  void _terminarGesto({bool cancelar = false}) {
    if (!_manteniendo) return;
    final estabaEsperando = _esperando;
    _manteniendo = false;
    _esperando = false;
    // Este dedo aún no inició su captura: no detener ni cancelar la
    // operación anterior, ni abrir el micrófono después de soltarlo.
    if (estabaEsperando) return;
    if (cancelar) {
      widget.onCancelar();
    } else {
      HapticFeedback.selectionClick();
      widget.onSoltar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducirMovimiento = MediaQuery.disableAnimationsOf(context);
    final colores = widget.coloresAnillo ?? AnilloAsistente.coloresPorDefecto;
    // Estos hijos no dependen de la expansión: reutilizarlos durante los
    // 280 ms de la animación conserva su layout y la pintura del avatar.
    final destinos = Row(
      children: [
        _destino(0, Icons.home_rounded, 'Inicio'),
        _destino(1, Icons.receipt_long_rounded, 'Movs'),
        const Expanded(child: SizedBox()),
        _destino(3, Icons.account_balance_rounded, 'Cuentas'),
        _destino(4, Icons.person_rounded, 'Perfil'),
      ],
    );
    final anillo = RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnilloAsistente(
            avatarBase64: widget.avatarBase64,
            colores: colores,
            size: 43,
          ),
          if (_dictadoHabilitado && widget.enviando)
            Positioned.fill(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colores.last,
              ),
            ),
        ],
      ),
    );
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _dictadoHabilitado && widget.pulsado ? 1 : 0),
          duration: reducirMovimiento
              ? Duration.zero
              : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, expansion, _) => SizedBox(
            height: BarraFlotante.altura,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _FondoBarra(
                          expansion: expansion,
                          nivel: reducirMovimiento || !_dictadoHabilitado
                              ? 0
                              : widget.nivel,
                          colores: colores,
                          nivelAudio: reducirMovimiento || !_dictadoHabilitado
                              ? null
                              : widget.nivelAudio,
                        ),
                      ),
                    ),
                  ),
                ),
                // --- Destinos: la fila queda inmóvil durante el dictado ---
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 0,
                  height: 64,
                  child: destinos,
                ),
                // --- Asistente: toque abre chat; mantener dicta; soltar envía ---
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Semantics(
                      button: true,
                      label: widget.nombreAsistente,
                      hint: _dictadoHabilitado
                          ? 'Toca para abrir el chat. Mantén pulsado para hablar y suelta para enviar.'
                          : 'Usa el micrófono del chat para hablar.',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPressDown: (_) {
                          if (_dictadoHabilitado) {
                            widget.onPrepararGesto?.call();
                          }
                        },
                        onTap: () {
                          if (!widget.ocupado) widget.onSeleccionar(2);
                        },
                        onLongPressStart: (_) {
                          if (!_dictadoHabilitado ||
                              (widget.ocupado && widget.pulsado)) {
                            return;
                          }
                          _manteniendo = true;
                          _esperando = widget.ocupado;
                          if (!_esperando) _iniciarDictado();
                        },
                        onLongPressEnd: (_) {
                          _terminarGesto();
                        },
                        onLongPressCancel: () {
                          _terminarGesto(cancelar: true);
                        },
                        child: SizedBox(
                          key: const ValueKey('boton-asistente-global'),
                          width: 76,
                          height: BarraFlotante.altura,
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              Positioned(
                                // En reposo queda dentro de los 64 dp de
                                // la píldora; sube junto al relieve central.
                                top: 48 - 34 * expansion,
                                child: Transform.scale(
                                  scale: 1 + 0.12 * expansion,
                                  child: anillo,
                                ),
                              ),
                              Positioned(
                                bottom: 20,
                                child: Opacity(
                                  opacity: expansion,
                                  child: Icon(
                                    Icons.mic_rounded,
                                    size: 14,
                                    color: colores.last,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _destino(int indice, IconData icono, String etiqueta) {
    final seleccionado = widget.indiceActual == indice;
    final color = seleccionado
        ? AppColors.primaryCyan
        : AppColors.textSecondary;
    return Expanded(
      child: Semantics(
        button: true,
        selected: seleccionado,
        label: etiqueta,
        child: InkResponse(
          key: ValueKey('destino-$indice'),
          onTap: () {
            if (widget.pulsado) widget.onCancelar();
            widget.onSeleccionar(indice);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                etiqueta,
                style: AppTextStyles.labelSm.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FondoBarra extends CustomPainter {
  _FondoBarra({
    required this.expansion,
    required this.nivel,
    required this.colores,
    this.nivelAudio,
  }) : super(repaint: nivelAudio);
  final double expansion, nivel;
  final ValueListenable<double>? nivelAudio;
  final List<Color> colores;

  @override
  void paint(Canvas canvas, Size size) {
    final nivel = nivelAudio?.value ?? this.nivel;
    const radio = 32.0;
    const superior = 42.0;
    final centro = size.width / 2;
    final ancho = 64 + 6 * expansion;
    final cima = superior - 40 * expansion;
    final contorno = Path()
      ..moveTo(radio, superior)
      ..lineTo(centro - ancho, superior)
      ..cubicTo(
        centro - ancho * .58,
        superior,
        centro - ancho * .65,
        cima,
        centro,
        cima,
      )
      ..cubicTo(
        centro + ancho * .65,
        cima,
        centro + ancho * .58,
        superior,
        centro + ancho,
        superior,
      )
      ..lineTo(size.width - radio, superior)
      ..arcToPoint(
        Offset(size.width, superior + radio),
        radius: const Radius.circular(radio),
      )
      ..arcToPoint(
        Offset(size.width - radio, size.height),
        radius: const Radius.circular(radio),
      )
      ..lineTo(radio, size.height)
      ..arcToPoint(
        const Offset(0, superior + radio),
        radius: const Radius.circular(radio),
      )
      ..arcToPoint(
        const Offset(radio, superior),
        radius: const Radius.circular(radio),
      )
      ..close();
    canvas.drawShadow(contorno, Colors.black.withValues(alpha: .5), 10, false);
    canvas.drawPath(contorno, Paint()..color = AppColors.surface1);
    canvas.save();
    canvas.clipPath(contorno);
    final halo = Rect.fromCircle(
      center: Offset(centro, 74 - 36 * expansion),
      radius: 68 + nivel * 8,
    );
    canvas.drawRect(
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [
            colores.first.withValues(
              alpha: .08 + expansion * (.14 + nivel * .12),
            ),
            colores.last.withValues(alpha: .03 + expansion * .06),
            Colors.transparent,
          ],
        ).createShader(halo),
    );
    canvas.restore();
    canvas.drawPath(
      contorno,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.glassStrokeHighlight,
    );
  }

  @override
  bool shouldRepaint(_FondoBarra oldDelegate) =>
      expansion != oldDelegate.expansion ||
      nivel != oldDelegate.nivel ||
      nivelAudio != oldDelegate.nivelAudio ||
      !listEquals(colores, oldDelegate.colores);
}
