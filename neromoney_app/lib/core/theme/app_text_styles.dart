/// Estilos tipográficos de "Obsidian Cyber-Glass".
///
/// Outfit para toda la UI y prosa; JetBrains Mono para cifras, timestamps y
/// metadatos técnicos (ver sección "Typography" de DESIGN.md).
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle _outfit({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacing = 0,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: weight,
      height: height / size,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle _mono({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacing = 0,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      height: height / size,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle get display =>
      _outfit(size: 40, weight: FontWeight.w700, height: 48, letterSpacing: -1.2);
  static TextStyle get headlineLg =>
      _outfit(size: 32, weight: FontWeight.w600, height: 38, letterSpacing: -0.64);
  static TextStyle get headlineMd =>
      _outfit(size: 24, weight: FontWeight.w600, height: 30, letterSpacing: -0.36);
  static TextStyle get headlineSm =>
      _outfit(size: 20, weight: FontWeight.w600, height: 26, letterSpacing: -0.2);
  static TextStyle get bodyLg => _outfit(size: 16, weight: FontWeight.w400, height: 24);
  static TextStyle get bodyMd =>
      _outfit(size: 14, weight: FontWeight.w400, height: 20, color: AppColors.textSecondary);
  static TextStyle get bodySm =>
      _outfit(size: 12, weight: FontWeight.w400, height: 16, color: AppColors.textSecondary);

  /// Para montos/saldos grandes. Usa `FontFeature.tabularFigures()` en el
  /// widget que la consuma si necesitas que las cifras no "salten" al cambiar.
  static TextStyle get numericHero =>
      _outfit(size: 36, weight: FontWeight.w700, height: 40, letterSpacing: -1.08);

  static TextStyle get labelCode => _mono(
        size: 11,
        weight: FontWeight.w500,
        height: 14,
        letterSpacing: 0.66,
        color: AppColors.textPlaceholder,
      );
  static TextStyle get labelSm =>
      _outfit(size: 11, weight: FontWeight.w600, height: 14, letterSpacing: 0.44);
}
