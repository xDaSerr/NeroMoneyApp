import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// El botón "Cyber-Action" del sistema de diseño: píldora con degradado
/// cian, glow permanente y una micro-animación al presionar (escala a 0.97
/// + oscurece 10%). Esta es la clase de micro-interacción que pediste para
/// que la app se sienta fluida sin exagerar — sutil, rápida (120ms) y en
/// cada botón importante de la app.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.colors = AppColors.ctaGradient,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final List<Color> colors;
  final bool expand;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          // Simula el "brightness: 90%" del spec sin filtros costosos.
          opacity: disabled ? 0.5 : (_pressed ? 0.9 : 1.0),
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.colors,
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: widget.colors.first.withValues(alpha: 0.3),
                        blurRadius: 18,
                        spreadRadius: 0,
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.label,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: AppColors.canvas,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(widget.icon, color: AppColors.canvas, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
