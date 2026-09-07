import 'app_colors.dart';

/// Las categorías de gasto/ingreso son texto libre (ver
/// `features/transactions/data/categoria.dart`), sin un color propio fijo
/// asignado — Inicio ("Gastos del mes") y Reportes reparten estos colores
/// en el orden en que aparece cada categoría, ciclando la lista.
const paletaCategorias = [
  AppColors.secondaryViolet,
  AppColors.primaryCyan,
  AppColors.outflowCrimson,
  AppColors.inflowEmerald,
];
