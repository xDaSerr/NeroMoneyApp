import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../onboarding/widgets/currency_picker.dart';

/// Diálogo para cambiar la moneda después del onboarding — el paso 1 del
/// onboarding (`onboarding_flow_screen.dart`) ya avisa "puedes cambiarla
/// después en Ajustes"; este diálogo es ese "Ajustes". Reutiliza
/// `monedasDisponibles` (la misma lista que usa el onboarding) para no
/// mantener dos copias.
///
/// Cambiarla es solo relabeling del símbolo — NUNCA convierte los montos ya
/// guardados (la app no hace conversión multi-moneda, ver CLAUDE.md), así
/// que el diálogo lo aclara antes de dejar elegir.
Future<void> mostrarSelectorMoneda({
  required BuildContext context,
  required String monedaActual,
  required ValueChanged<String> onElegir,
}) {
  return showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(24), // las 4 esquinas
          border: Border.all(color: AppColors.glassStrokeStandard),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Moneda', style: AppTextStyles.headlineSm),
                const SizedBox(height: 6),
                Text(
                  'Solo cambia el símbolo que ves — no convierte los montos que '
                  'ya tienes guardados.',
                  style: AppTextStyles.bodySm,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: monedasDisponibles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final opcion = monedasDisponibles[i];
                      final seleccionada = opcion.codigo == monedaActual;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          onElegir(opcion.codigo);
                          Navigator.of(dialogContext).pop();
                        },
                        child: GlassCard(
                          color: seleccionada
                              ? AppColors.primaryCyan.withValues(alpha: 0.12)
                              : AppColors.surface2Glass,
                          child: Row(
                            children: [
                              Text(
                                opcion.bandera,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(opcion.codigo, style: AppTextStyles.bodyLg),
                                    Text(opcion.nombre, style: AppTextStyles.bodySm),
                                  ],
                                ),
                              ),
                              if (seleccionada)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primaryCyan,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
