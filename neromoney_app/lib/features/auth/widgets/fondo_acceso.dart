import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Fondo de las pantallas de acceso: la imagen de vidrio cian/violeta con un
/// zoom muy lento de ida y vuelta (efecto "Ken Burns"), para que la portada
/// se sienta viva sin distraer del formulario. Si el sistema pide reducir
/// movimiento, la imagen se queda quieta.
class FondoAcceso extends StatefulWidget {
  const FondoAcceso({super.key});

  // 3840×2160 en WebP (pesa menos que la versión anterior en JPG de 1672 px).
  static const ruta = 'assets/img/fondo_auth.webp';
  static const _anchoOriginal = 3840;

  /// Ancho al que conviene decodificar la imagen para cubrir esta pantalla.
  /// Decodificar el 4K completo en un teléfono gastaría ~33 MB de memoria
  /// para nada; se redondea a múltiplos de 512 para no volver a decodificar
  /// con cada pixel que cambie el tamaño de la ventana.
  static int anchoDecodificado(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Con BoxFit.cover, una pantalla vertical obliga a cubrir el alto: el
    // ancho necesario sale de la proporción 16:9 de la imagen.
    final necesario =
        (size.width > size.height * 16 / 9
            ? size.width
            : size.height * 16 / 9) *
        dpr *
        1.03; // el zoom lento agranda hasta 3%
    final redondeado = ((necesario / 512).ceil() * 512);
    return redondeado.clamp(512, _anchoOriginal);
  }

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
            // Solo 3%: cada punto de zoom agranda los píxeles de la imagen y
            // con 7% ya se notaba borrosa en monitores grandes.
            scale: 1 + 0.03 * Curves.easeInOut.transform(_zoom.value),
            child: child,
          ),
          child: Image.asset(
            FondoAcceso.ruta,
            fit: BoxFit.cover,
            cacheWidth: FondoAcceso.anchoDecodificado(context),
            // Al reducir/agrandar la imagen al tamaño exacto de la pantalla,
            // el filtro "high" (bicúbico) la deja más nítida que el de por
            // defecto.
            filterQuality: FilterQuality.high,
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
