import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Colores que el usuario puede elegir para personalizar una cuenta — se
/// guardan como el entero ARGB (`Color.value`) en `Cuenta.colorPersonalizado`.
/// Si no elige ninguno, `CuentaTile` cae en el color por defecto según el
/// tipo (violeta para crédito, vidrio normal para el resto).
const paletaColoresCuentas = <Color>[
  AppColors.secondaryViolet,
  AppColors.primaryCyan,
  AppColors.inflowEmerald,
  AppColors.outflowCrimson,
  Color(0xFFF59E0B), // ámbar
  Color(0xFF3B82F6), // azul
  Color(0xFFEC4899), // rosa
  Color(0xFF14B8A6), // verde azulado
];
