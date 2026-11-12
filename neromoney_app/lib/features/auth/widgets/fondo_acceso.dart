import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/theme/app_colors.dart';

/// Fondo de las pantallas de acceso: la imagen de listones de vidrio
/// cian/violeta, animada por un shader (shaders/fondo_ondas.frag) que la hace
/// ondular despacio a los lados y le pasa un reflejo de luz por los bordes de
/// neón. Si el sistema pide reducir movimiento, o el shader no se puede
/// cargar en este dispositivo, se muestra la imagen fija.
class FondoAcceso extends StatefulWidget {
  const FondoAcceso({super.key});

  // 3840×2160 en WebP, reescalada con Upscayl para que los bordes de neón se
  // vean nítidos en monitores grandes.
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
        1.03; // margen para el acercamiento del shader
    final redondeado = ((necesario / 512).ceil() * 512);
    return redondeado.clamp(512, _anchoOriginal);
  }

  // Se compila una sola vez por ejecución de la app; si falla (dispositivo
  // sin soporte), todas las instancias usan la imagen fija.
  static Future<ui.FragmentProgram>? _programa;
  static Future<ui.FragmentProgram> _cargarPrograma() =>
      _programa ??= ui.FragmentProgram.fromAsset('shaders/fondo_ondas.frag');

  @override
  State<FondoAcceso> createState() => _FondoAccesoState();
}

class _FondoAccesoState extends State<FondoAcceso>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  ui.Image? _imagen;
  int? _anchoCargado;
  ImageStream? _flujo;
  ImageStreamListener? _oyente;
  bool _shaderFallo = false;

  // El tiempo vive en un ValueNotifier para repintar solo el CustomPaint en
  // cada cuadro, sin reconstruir el resto de la pantalla.
  final _tiempo = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (transcurrido) => _tiempo.value = transcurrido.inMicroseconds / 1e6,
  );

  @override
  void initState() {
    super.initState();
    FondoAcceso._cargarPrograma().then(
      (programa) {
        if (mounted) setState(() => _shader = programa.fragmentShader());
      },
      onError: (Object _) {
        if (mounted) setState(() => _shaderFallo = true);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animar = !MediaQuery.disableAnimationsOf(context);
    if (animar && !_ticker.isActive) _ticker.start();
    if (!animar && _ticker.isActive) _ticker.stop();

    final ancho = FondoAcceso.anchoDecodificado(context);
    if (animar && ancho != _anchoCargado) _cargarImagen(ancho);
  }

  /// El shader necesita la imagen ya decodificada (ui.Image), no un widget
  /// Image: se resuelve a mano con el mismo tamaño que usaría Image.asset.
  void _cargarImagen(int ancho) {
    _anchoCargado = ancho;
    _quitarOyente();
    final flujo = ResizeImage(
      const AssetImage(FondoAcceso.ruta),
      width: ancho,
    ).resolve(createLocalImageConfiguration(context));
    final oyente = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() {
        _imagen?.dispose();
        _imagen = info.image.clone();
      });
      info.dispose();
    });
    flujo.addListener(oyente);
    _flujo = flujo;
    _oyente = oyente;
  }

  void _quitarOyente() {
    if (_flujo != null && _oyente != null) _flujo!.removeListener(_oyente!);
    _flujo = null;
    _oyente = null;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tiempo.dispose();
    _quitarOyente();
    _imagen?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animado =
        !MediaQuery.disableAnimationsOf(context) &&
        !_shaderFallo &&
        _shader != null &&
        _imagen != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.canvas),
        // La imagen fija siempre está debajo: es lo que se ve mientras carga
        // el shader, y el respaldo si no hay animación.
        Image.asset(
          FondoAcceso.ruta,
          fit: BoxFit.cover,
          cacheWidth: FondoAcceso.anchoDecodificado(context),
          // El filtro "high" (bicúbico) la deja más nítida al ajustarla al
          // tamaño exacto de la pantalla.
          filterQuality: FilterQuality.high,
          frameBuilder: (context, child, frame, sincrono) => AnimatedOpacity(
            opacity: sincrono || frame != null ? 1 : 0,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            child: child,
          ),
        ),
        if (animado)
          // Al aparecer encima de la imagen fija no se nota el cambio: en el
          // instante 0 el shader pinta casi la misma imagen.
          CustomPaint(
            painter: _PintorOndas(
              shader: _shader!,
              imagen: _imagen!,
              tiempo: _tiempo,
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

class _PintorOndas extends CustomPainter {
  _PintorOndas({
    required this.shader,
    required this.imagen,
    required this.tiempo,
  }) : super(repaint: tiempo);

  final ui.FragmentShader shader;
  final ui.Image imagen;
  final ValueNotifier<double> tiempo;

  @override
  void paint(Canvas canvas, Size size) {
    // El orden de los setFloat sigue el de los uniform en el .frag.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, imagen.width.toDouble())
      ..setFloat(3, imagen.height.toDouble())
      ..setFloat(4, tiempo.value)
      // Por defecto el sampler lee sin suavizar (vecino más cercano) y la
      // ondulación se vería pixelada; bilineal basta porque la imagen ya
      // viene decodificada al tamaño de la pantalla.
      ..setImageSampler(0, imagen, filterQuality: FilterQuality.low);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_PintorOndas old) =>
      old.imagen != imagen || old.shader != shader;
}
