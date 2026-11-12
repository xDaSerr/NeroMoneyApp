import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fondo de la app por dentro (no el del acceso, que usa la imagen): el
/// color base del tema con dos resplandores difusos de sus colores en
/// esquinas opuestas, como en el diseño de escritorio que pidió el usuario.
/// Dibujado con degradados, así que se ve nítido en cualquier tamaño y
/// cambia solo con el tema.
class FondoTema extends StatelessWidget {
  const FondoTema({super.key});

  @override
  Widget build(BuildContext context) {
    final paleta = AppColors.paleta;
    // En el tema claro los resplandores van más tenues: sobre blanco, la
    // misma intensidad se ve como una mancha.
    final intensidad = paleta.esClaro ? 0.18 : 0.22;
    return DecoratedBox(
      decoration: BoxDecoration(color: paleta.canvas),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-1.1, 1.1),
                radius: 0.9,
                colors: [
                  paleta.resplandores[0].withValues(alpha: intensidad),
                  paleta.resplandores[0].withValues(alpha: 0),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(1.1, 1.0),
                radius: 0.8,
                colors: [
                  paleta.resplandores[1].withValues(alpha: intensidad),
                  paleta.resplandores[1].withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
