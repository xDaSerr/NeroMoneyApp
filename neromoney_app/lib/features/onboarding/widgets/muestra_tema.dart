import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/tema_app.dart';

/// Un color de la cuadrícula: un mini "fondo" del tema con su degradado
/// encima, para que se vea la combinación y no solo un punto de color. Se
/// usa también en el selector de color de Perfil.
class MuestraTema extends StatelessWidget {
  const MuestraTema({
    super.key,
    required this.tema,
    required this.seleccionado,
    required this.onTap,
  });

  final TemaApp tema;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paleta = PaletaTema.de(tema);
    return Semantics(
      button: true,
      selected: seleccionado,
      label: 'Color ${tema.etiqueta}',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: paleta.canvas,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: seleccionado
                        ? AppColors.acento
                        : AppColors.glassStrokeHighlight,
                    width: seleccionado ? 2.5 : 1,
                  ),
                  boxShadow: seleccionado
                      ? [
                          BoxShadow(
                            color: AppColors.brilloAcento,
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: paleta.degradadoAccion,
                      ),
                    ),
                    child: seleccionado
                        ? Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: paleta.sobreAcento,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tema.etiqueta,
              style: AppTextStyles.bodySm.copyWith(
                color: seleccionado
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
