import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/membresia.dart';

/// "Esto es de Plus": explica qué desbloquea y lleva a la pantalla de
/// planes. Se usa cuando alguien en Gratis llega a un límite.
Future<void> mostrarAvisoPlan(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  PlanNero plan = PlanNero.plus,
}) {
  return showDialog(
    context: context,
    builder: (dialogo) => Dialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.acento.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.acento,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(titulo, style: AppTextStyles.headlineMd),
              const SizedBox(height: 8),
              Text(
                mensaje,
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogo),
                    child: const Text('Ahora no'),
                  ),
                  const SizedBox(width: 8),
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
                    onPressed: () {
                      Navigator.pop(dialogo);
                      context.push('/planes');
                    },
                    child: Text('Ver ${plan.nombre}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
