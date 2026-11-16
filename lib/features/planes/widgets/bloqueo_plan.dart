import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/membresia.dart';

/// Muestra [child] borroso, sin poder tocarlo, con el botón para pasar a
/// [plan]. Para enseñar qué hay detrás sin dárselo a quien no lo tiene.
class BloqueoPlan extends StatelessWidget {
  const BloqueoPlan({
    super.key,
    required this.child,
    required this.plan,
    this.texto,
  });

  final Widget child;
  final PlanNero plan;
  final String? texto;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: child,
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.acento),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.acento,
                foregroundColor: AppColors.sobreAcento,
                textStyle: AppTextStyles.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              onPressed: () => context.push('/planes'),
              child: Text(texto ?? 'Desbloquear con ${plan.nombre}'),
            ),
          ],
        ),
      ],
    );
  }
}
