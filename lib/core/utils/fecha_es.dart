/// Nombres de mes en español, en minúsculas — así se usan en frases sueltas
/// ("gastos de octubre"). Compartido entre Inicio y Reportes para no tener
/// dos copias de la misma lista (antes vivía duplicada, privada, dentro de
/// home_screen.dart).
const mesesEs = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// El nombre del mes con mayúscula inicial, para títulos ("Octubre 2026").
String mesCapitalizado(int mes) {
  final nombre = mesesEs[mes - 1];
  return '${nombre[0].toUpperCase()}${nombre.substring(1)}';
}
