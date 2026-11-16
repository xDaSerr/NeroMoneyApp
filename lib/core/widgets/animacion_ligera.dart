import 'package:flutter/foundation.dart';

/// En teléfonos (app Android o la web abierta en un teléfono) las
/// transiciones no desenfocan lo que aparece: animar el desenfoque obliga a
/// redibujar y filtrar todo el panel en cada cuadro y, en la web, a compilar
/// un filtro distinto por cada valor, y se veía "cuadro por cuadro". Ahí la
/// entrada usa solo opacidad y escala, que el teléfono mueve sin esfuerzo.
bool get animacionLigera =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;
