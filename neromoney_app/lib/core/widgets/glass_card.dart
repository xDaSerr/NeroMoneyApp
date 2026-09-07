import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Tarjeta de vidrio esmerilado ("Level 1/2" de DESIGN.md): desenfoca lo que
/// hay detrás con [BackdropFilter] y le pone un borde muy sutil de 1px que
/// simula el bisel de vidrio. Es la base visual de casi todas las tarjetas
/// de la app (cuentas, movimientos, burbujas del asistente).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.color = AppColors.surface2Glass,
    this.blurSigma = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color color;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.glassStrokeStandard),
          ),
          child: child,
        ),
      ),
    );
  }
}
