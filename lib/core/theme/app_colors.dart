/// Colores de la app, leídos de la paleta del tema activo (ver tema_app.dart).
///
/// Antes eran constantes fijas del diseño "Obsidian Cyber-Glass" (Stitch);
/// ese diseño sigue siendo el tema "Negro". Como ahora el usuario elige el
/// color de su app, todo pasa por getters: cambiar de tema es cambiar la
/// paleta y reconstruir la app (ver ControladorTema). Por eso estos valores
/// ya no pueden usarse dentro de un `const`.
library;

import 'package:flutter/material.dart';

import 'tema_app.dart';

class AppColors {
  AppColors._();

  static PaletaTema _paleta = PaletaTema.de(TemaApp.negro);
  static PaletaTema get paleta => _paleta;

  /// Solo ControladorTema/main.dart deben llamarlo: después de cambiar la
  /// paleta hay que reconstruir los widgets para que la lean de nuevo.
  static void aplicar(PaletaTema paleta) => _paleta = paleta;

  // Fondo y superficies
  static Color get canvas => _paleta.canvas;
  static Color get surface1 => _paleta.surface1;
  static Color get surface2Glass => _paleta.surface2Glass;
  static Color get surface3ActiveGlass => _paleta.surface3ActiveGlass;

  // Acentos del tema
  static Color get acento => _paleta.acento;
  static Color get acentoPresionado => _paleta.acentoPresionado;
  static Color get sobreAcento => _paleta.sobreAcento;
  static Color get secundario => _paleta.secundario;
  static Color get secundarioClaro => _paleta.secundarioClaro;
  static Color get secundarioProfundo => _paleta.secundarioProfundo;
  static Color get brilloAcento => _paleta.brilloAcento;

  /// Base de las tarjetas que imitan una tarjeta física (CuentaTile, detalle
  /// de cuenta): siempre oscura, con texto blanco, también en el tema Blanco
  /// — una tarjeta clara con texto blanco no se leería.
  static Color get fondoTarjetaFisica =>
      _paleta.esClaro ? const Color(0xFF161B2E) : _paleta.canvas;

  /// Acentos para usar ENCIMA de esas tarjetas oscuras: en el tema claro el
  /// acento normal es oscuro (para leerse sobre blanco) y sobre la tarjeta
  /// casi desaparecía.
  static Color get acentoEnTarjeta =>
      _paleta.esClaro ? const Color(0xFF818CF8) : _paleta.acento;
  static Color get secundarioEnTarjeta =>
      _paleta.esClaro ? const Color(0xFFA78BFA) : _paleta.secundario;

  // Semántica financiera: igual en todos los temas, para que verde siempre
  // signifique ingreso y rojo siempre gasto.
  static const Color inflowEmerald = Color(0xFF10B981); // ingresos
  static const Color outflowCrimson = Color(0xFFF43F5E); // gastos

  // Texto
  static Color get textPrimary => _paleta.textPrimary;
  static Color get textSecondary => _paleta.textSecondary;
  static Color get textPlaceholder => _paleta.textPlaceholder;

  // Bordes / vidrio
  static Color get glassStrokeStandard => _paleta.glassStrokeStandard;
  static Color get glassStrokeHighlight => _paleta.glassStrokeHighlight;

  // Degradados
  static List<Color> get degradadoAccion => _paleta.degradadoAccion;
  static List<Color> get degradadoBurbuja => _paleta.degradadoBurbuja;
}
