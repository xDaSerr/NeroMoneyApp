import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'tema_app.dart';

/// Las categorías de gasto/ingreso son texto libre (ver
/// `features/transactions/data/categoria.dart`), sin un color propio fijo
/// asignado — Inicio ("Gastos del mes") y Reportes reparten estos colores
/// en el orden en que aparece cada categoría, ciclando la lista.
///
/// Sigue al tema elegido (los dos primeros son sus acentos). En los temas
/// rojizos el tercer color cambia a verde azulado: un carmesí ahí se
/// confundiría con el acento.
List<Color> get paletaCategorias => [
  AppColors.secundario,
  AppColors.acento,
  switch (AppColors.paleta.tema) {
    TemaApp.rojo || TemaApp.rosa || TemaApp.naranja => const Color(0xFF14B8A6),
    _ => AppColors.outflowCrimson,
  },
  AppColors.inflowEmerald,
];
