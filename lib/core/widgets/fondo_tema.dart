import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tema_app.dart';

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
    final fondo = paleta.fondo;
    if (fondo != null) return _FondoImagen(fondo: fondo, canvas: paleta.canvas);
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

/// Fondo con imagen (Plus y Pro). La imagen cubre toda la ventana; encima
/// va un velo oscuro un poco más fuerte en el centro, donde están el texto
/// y las tarjetas, para que siempre se lea bien. Mientras carga se ve el
/// color base, y la imagen aparece con un fundido.
class _FondoImagen extends StatelessWidget {
  const _FondoImagen({required this.fondo, required this.canvas});

  final FondoApp fondo;
  final Color canvas;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: canvas),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            fondo.imagen,
            key: ValueKey(fondo),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            frameBuilder: (context, hijo, cuadro, sincrono) => sincrono
                ? hijo
                : AnimatedOpacity(
                    opacity: cuadro == null ? 0 : 1,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    child: hijo,
                  ),
            // Si la imagen no carga, queda el color base: nunca una pantalla
            // rota.
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.0,
                colors: [
                  canvas.withValues(alpha: 0.55),
                  canvas.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
