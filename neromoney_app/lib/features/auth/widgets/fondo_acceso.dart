import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Fondo de las pantallas de acceso: la imagen de vidrio cian/violeta con un
/// zoom muy lento de ida y vuelta (efecto "Ken Burns"), para que la portada
/// se sienta viva sin distraer del formulario. Si el sistema pide reducir
/// movimiento, la imagen se queda quieta.
class FondoAcceso extends StatefulWidget {
  const FondoAcceso({super.key});

  static const ruta = 'assets/img/fondo_auth.jpg';

  @override
  State<FondoAcceso> createState() => _FondoAccesoState();
}

class _FondoAccesoState extends State<FondoAcceso>
    with SingleTickerProviderStateMixin {
  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _zoom.stop();
    } else if (!_zoom.isAnimating) {
      _zoom.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.canvas),
        AnimatedBuilder(
          animation: _zoom,
          builder: (context, child) => Transform.scale(
            scale: 1 + 0.07 * Curves.easeInOut.transform(_zoom.value),
            child: child,
          ),
          child: Image.asset(
            FondoAcceso.ruta,
            fit: BoxFit.cover,
            // Aparece con un fundido en vez de "saltar" cuando termina de
            // decodificarse.
            frameBuilder: (context, child, frame, sincrono) => AnimatedOpacity(
              opacity: sincrono || frame != null ? 1 : 0,
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              child: child,
            ),
          ),
        ),
        // En pantallas angostas (teléfono) la imagen se recorta al centro,
        // que es casi negro; este degradado mantiene legible el texto
        // también cuando los listones de color quedan detrás.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.9,
              colors: [Color(0x99050810), Color(0x00050810)],
            ),
          ),
        ),
      ],
    );
  }
}
