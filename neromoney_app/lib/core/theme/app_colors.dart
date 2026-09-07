/// Paleta de colores del sistema de diseño "Obsidian Cyber-Glass".
///
/// Estos valores vienen directo de la guía de estilo generada en Stitch
/// (stitch_neromoney_ai_finance_app/obsidian_cyber_glass/DESIGN.md), para que
/// la app en Flutter se vea idéntica a las pantallas de referencia.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Fondo base ("Obsidian")
  static const Color canvas = Color(0xFF0A0D14);
  static const Color surface1 = Color(0xFF121826); // tarjetas, hojas base
  static const Color surface2Glass = Color(0xB3121826); // rgba(18,24,38,.70)
  static const Color surface3ActiveGlass = Color(0x0AFFFFFF); // rgba(255,255,255,.04)

  // Acentos de marca
  static const Color primaryCyan = Color(0xFF00F0FF);
  static const Color primaryCyanPressed = Color(0xFF00D2FF);
  static const Color secondaryViolet = Color(0xFF8A2BE2);
  static const Color secondaryVioletTint = Color(0xFFA855F7);
  static const Color secondaryVioletDeep = Color(0xFF7B2CBF);

  // Semántica financiera
  static const Color inflowEmerald = Color(0xFF10B981); // ingresos
  static const Color outflowCrimson = Color(0xFFF43F5E); // gastos

  // Texto
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textPlaceholder = Color(0xFF64748B);

  // Bordes / vidrio
  static const Color glassStrokeStandard = Color(0x14FFFFFF); // rgba(255,255,255,.08)
  static const Color glassStrokeHighlight = Color(0x29FFFFFF); // rgba(255,255,255,.16)
  static const Color cyanGlowAccent = Color(0x4000F0FF); // rgba(0,240,255,.25)

  // Gradiente del botón principal (CTA)
  static const List<Color> ctaGradient = [primaryCyan, Color(0xFF00B4D8)];

  // Gradiente de burbuja del usuario en el chat
  static const List<Color> userBubbleGradient = [secondaryVioletDeep, Color(0xFF5A189A)];
}
