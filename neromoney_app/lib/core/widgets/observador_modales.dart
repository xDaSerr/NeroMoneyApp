import 'package:flutter/widgets.dart';

/// Cuenta cuántos paneles y diálogos hay abiertos en el navegador raíz.
///
/// MarcoEscritorio dibuja el botón "Hablar con…" por encima del navegador
/// (vive fuera del router), así que quedaba encima de los paneles: tapaba
/// los botones "Crear" y "×" del panel de un movimiento y se llevaba el
/// toque. Con esto el marco lo esconde mientras haya algo abierto.
class ObservadorModales extends NavigatorObserver {
  final abiertos = ValueNotifier<int>(0);

  // Diálogos y menús (PopupRoute) y los paneles que salen de un botón
  // (rutas no opacas, ver BotonConPanel).
  static bool _esModal(Route<dynamic>? ruta) =>
      ruta is PopupRoute || (ruta is PageRoute && !ruta.opaque);

  void _sumar(Route<dynamic>? ruta, int cambio) {
    if (!_esModal(ruta)) return;
    abiertos.value = (abiertos.value + cambio).clamp(0, 1 << 20);
  }

  @override
  void didPush(Route<dynamic> ruta, Route<dynamic>? anterior) =>
      _sumar(ruta, 1);

  @override
  void didPop(Route<dynamic> ruta, Route<dynamic>? anterior) =>
      _sumar(ruta, -1);

  @override
  void didRemove(Route<dynamic> ruta, Route<dynamic>? anterior) =>
      _sumar(ruta, -1);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _sumar(oldRoute, -1);
    _sumar(newRoute, 1);
  }
}

/// El del navegador raíz de la app (ver app_router.dart).
final observadorModales = ObservadorModales();
