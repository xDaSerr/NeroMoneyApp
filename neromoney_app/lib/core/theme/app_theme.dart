import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// ThemeData único de la app. Todo se arma sobre modo oscuro porque el
/// diseño "Obsidian Cyber-Glass" no contempla modo claro (es la base de
/// marca, no una preferencia de accesibilidad que alternar).
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      surface: AppColors.canvas,
      primary: AppColors.primaryCyan,
      onPrimary: AppColors.canvas,
      secondary: AppColors.secondaryViolet,
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
      brightness: Brightness.dark,
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
          side: const BorderSide(color: AppColors.glassStrokeStandard),
        ),
      ),

      // Botón principal (fallback sólido; para el gradiente real usa
      // el widget GradientButton en core/widgets).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryCyan,
          foregroundColor: AppColors.canvas,
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
        hintStyle: AppTextStyles.bodyLg.copyWith(color: AppColors.textPlaceholder),
        labelStyle: AppTextStyles.labelCode,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassStrokeStandard),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassStrokeStandard),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryCyan, width: 1.5),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.glassStrokeStandard,
        thickness: 1,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface1,
        indicatorColor: AppColors.primaryCyan.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(AppTextStyles.labelSm),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
