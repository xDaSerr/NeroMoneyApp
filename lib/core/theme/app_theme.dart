import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// ThemeData de la app, armado con la paleta del tema activo (ver
/// tema_app.dart): oscuro en 7 de los 8 colores y claro en "Blanco".
class AppTheme {
  AppTheme._();

  static ThemeData get actual {
    final claro = AppColors.paleta.esClaro;
    final constructor = claro ? ColorScheme.light : ColorScheme.dark;
    final colorScheme = constructor(
      surface: AppColors.canvas,
      primary: AppColors.acento,
      onPrimary: AppColors.sobreAcento,
      secondary: AppColors.secundario,
      onSecondary: AppColors.textPrimary,
      tertiary: AppColors.inflowEmerald,
      error: AppColors.outflowCrimson,
      onError: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surface1,
      outline: AppColors.glassStrokeStandard,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: claro ? Brightness.light : Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: AppTextStyles.bodyLg.fontFamily,
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display,
        headlineLarge: AppTextStyles.headlineLg,
        headlineMedium: AppTextStyles.headlineMd,
        headlineSmall: AppTextStyles.headlineSm,
        bodyLarge: AppTextStyles.bodyLg,
        bodyMedium: AppTextStyles.bodyMd,
        bodySmall: AppTextStyles.bodySm,
        labelLarge: AppTextStyles.labelSm,
        labelSmall: AppTextStyles.labelCode,
      ),

      // Tarjetas: base de "Level 1 (Card Matrix)" — el blur real de vidrio se
      // aplica con BackdropFilter en GlassCard, esto solo fija el look base.
      cardTheme: CardThemeData(
        color: AppColors.surface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.glassStrokeStandard),
        ),
      ),

      // Botón principal (fallback sólido; para el gradiente real usa
      // el widget GradientButton en core/widgets).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.acento,
          foregroundColor: AppColors.sobreAcento,
          textStyle: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          minimumSize: const Size.fromHeight(56),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          textStyle: AppTextStyles.bodyMd,
        ),
      ),

      // Campos de texto tipo "vidrio flotante" (ver sección 5 de DESIGN.md).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface3ActiveGlass,
        hintStyle: AppTextStyles.bodyLg.copyWith(
          color: AppColors.textPlaceholder,
        ),
        labelStyle: AppTextStyles.labelCode,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.glassStrokeStandard),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.glassStrokeStandard),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.acento, width: 1.5),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.glassStrokeStandard,
        thickness: 1,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface1,
        indicatorColor: AppColors.acento.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(AppTextStyles.labelSm),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
