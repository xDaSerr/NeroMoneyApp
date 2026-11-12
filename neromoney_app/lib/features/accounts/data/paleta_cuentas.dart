import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Colores que el usuario puede elegir para personalizar una cuenta — se
/// guardan como el entero ARGB (`Color.value`) en `Cuenta.colorPersonalizado`.
/// Si no elige ninguno, `CuentaTile` cae en el color por defecto según el
/// tipo (violeta para crédito, vidrio normal para el resto).
///
/// Valores fijos a propósito (no los colores del tema activo): el ARGB elegido
/// se guarda en Firestore y la cuenta no debe cambiar de color si el usuario
/// cambia el tema de la app.
const paletaColoresCuentas = <Color>[
  Color(0xFF8A2BE2), // violeta
  Color(0xFF00F0FF), // cian
  AppColors.inflowEmerald,
  AppColors.outflowCrimson,
  Color(0xFFF59E0B), // ámbar
  Color(0xFF3B82F6), // azul
  Color(0xFFEC4899), // rosa
  Color(0xFF14B8A6), // verde azulado
];
