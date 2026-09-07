import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

/// Pantalla temporal para las secciones que todavía no construimos a
/// detalle. Se reemplaza sección por sección conforme avancemos.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(title, style: AppTextStyles.headlineMd),
      ),
    );
  }
}
