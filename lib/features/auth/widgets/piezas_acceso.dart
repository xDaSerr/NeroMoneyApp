import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// "NeroMoney." con el punto en cian, como en el diseño de la tarjeta.
class LogoNeroMoney extends StatelessWidget {
  const LogoNeroMoney({super.key, this.tamano = 26});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    final estilo = AppTextStyles.headlineMd.copyWith(
      fontSize: tamano,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    );
    return Text.rich(
      TextSpan(
        style: estilo,
        children: [
          TextSpan(text: 'NeroMoney'),
          TextSpan(
            text: '.',
            style: TextStyle(color: AppColors.acento),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de vidrio grande donde viven los formularios de acceso. Más
/// translúcida y con más desenfoque que `GlassCard`, porque aquí lo que hay
/// detrás es la imagen de fondo y se quiere que se alcance a ver a través.
class TarjetaAcceso extends StatelessWidget {
  const TarjetaAcceso({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final angosto = MediaQuery.sizeOf(context).width < 520;
    final radio = BorderRadius.circular(28);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radio,
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 60,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radio,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: angosto ? 24 : 48,
              vertical: angosto ? 32 : 44,
            ),
            decoration: BoxDecoration(
              borderRadius: radio,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xB3141A28), Color(0x990C101A)],
              ),
              border: Border.all(color: AppColors.glassStrokeHighlight),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Etiqueta de campo en tipo oración ("Correo electrónico"), como en el
/// diseño de la tarjeta — no en mayúsculas monoespaciadas como el resto de
/// la app, para que el acceso se sienta más cálido.
class EtiquetaCampo extends StatelessWidget {
  const EtiquetaCampo(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: AppTextStyles.bodyMd.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Botón secundario de vidrio (borde fino, fondo translúcido) con la misma
/// micro-interacción que `GradientButton`: crece un poco al pasar el mouse
/// y se encoge al presionar.
class BotonVidrio extends StatefulWidget {
  const BotonVidrio({
    super.key,
    required this.label,
    required this.onPressed,
    this.icono,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icono;

  @override
  State<BotonVidrio> createState() => _BotonVidrioState();
}

class _BotonVidrioState extends State<BotonVidrio> {
  bool _encima = false;
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final activo = widget.onPressed != null;
    final escala = _presionado ? 0.97 : (_encima ? 1.02 : 1.0);
    return MouseRegion(
      cursor: activo ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: GestureDetector(
        onTapDown: activo ? (_) => setState(() => _presionado = true) : null,
        onTapUp: activo ? (_) => setState(() => _presionado = false) : null,
        onTapCancel: () => setState(() => _presionado = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: escala,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: _encima
                  ? const Color(0x1AFFFFFF)
                  : const Color(0x0DFFFFFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _encima
                    ? AppColors.acento.withValues(alpha: 0.6)
                    : const Color(0x33FFFFFF),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icono != null) ...[
                  widget.icono!,
                  const SizedBox(width: 12),
                ],
                Text(
                  widget.label,
                  style: AppTextStyles.bodyLg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La "G" de Google en sus cuatro colores, dibujada a mano para no agregar
/// una dependencia de SVG solo por este ícono.
class LogoGoogle extends StatelessWidget {
  const LogoGoogle({super.key, this.tamano = 22});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: tamano,
      child: CustomPaint(painter: _PintorG()),
    );
  }
}

class _PintorG extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grosor = size.width * 0.2;
    final centro = size.center(Offset.zero);
    final radio = (size.width - grosor) / 2;
    final rect = Rect.fromCircle(center: centro, radius: radio);
    Paint pincel(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;
    double g(double grados) => grados * math.pi / 180;

    canvas.drawArc(
      rect,
      g(-140),
      g(100),
      false,
      pincel(const Color(0xFFEA4335)),
    );
    canvas.drawArc(rect, g(135), g(85), false, pincel(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, g(40), g(95), false, pincel(const Color(0xFF34A853)));
    canvas.drawArc(rect, g(0), g(40), false, pincel(const Color(0xFF4285F4)));
    canvas.drawRect(
      Rect.fromLTWH(
        centro.dx,
        centro.dy - grosor / 2,
        radio + grosor / 2,
        grosor,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Separador "—— o ——" entre el acceso con correo y el de Google.
class SeparadorO extends StatelessWidget {
  const SeparadorO({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0x33FFFFFF))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('o', style: AppTextStyles.bodyMd),
        ),
        const Expanded(child: Divider(color: Color(0x33FFFFFF))),
      ],
    );
  }
}

/// Texto + enlace en cian ("¿Primera vez aquí? Crea tu cuenta").
class EnlaceAcceso extends StatelessWidget {
  const EnlaceAcceso({
    super.key,
    required this.texto,
    required this.enlace,
    required this.onTap,
  });

  final String texto;
  final String enlace;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$texto ', style: AppTextStyles.bodyMd),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Text(
              enlace,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.acento,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mensaje de error de los formularios. Aparece con una sacudida corta para
/// que se note aunque el usuario esté mirando el botón, no el texto. La key
/// por texto hace que un error distinto vuelva a sacudirse.
class MensajeErrorAcceso extends StatelessWidget {
  const MensajeErrorAcceso(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child:
          Text(
                texto,
                key: ValueKey(texto),
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.outflowCrimson,
                ),
              )
              .animate(key: ValueKey(texto))
              .fadeIn(duration: 150.ms)
              .shakeX(hz: 5, amount: 4, duration: 350.ms),
    );
  }
}
