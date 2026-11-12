import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Combinaciones de 2 colores para el anillo degradado alrededor de la cara
/// del asistente (ver AnilloAsistente). La primera es la que se usaba fija
/// antes de que esto fuera elegible — se deja primero para que sea la que
/// aparece preseleccionada la primera vez que alguien abre
/// PersonalizarAsistenteScreen.
///
/// Valores fijos (no los del tema activo): se guardan en Firestore y el
/// anillo elegido no debe cambiar solo al cambiar el tema de la app.
const _violeta = Color(0xFFA855F7);
const _cian = Color(0xFF00F0FF);
const paletaAnillosAsistente = <List<Color>>[
  [_violeta, _cian], // Violeta → Cian
  [_cian, AppColors.inflowEmerald], // Cian → Esmeralda
  [AppColors.inflowEmerald, Color(0xFFF59E0B)], // Esmeralda → Ámbar
  [Color(0xFFF59E0B), AppColors.outflowCrimson], // Ámbar → Carmesí
  [AppColors.outflowCrimson, Color(0xFFEC4899)], // Carmesí → Rosa
  [Color(0xFFEC4899), _violeta], // Rosa → Violeta
];
