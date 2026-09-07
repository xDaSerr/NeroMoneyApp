import 'package:flutter/material.dart';

/// Categorías fijas por ahora (alcance MVP). Más adelante se vuelven
/// personalizables por el usuario.
class Categoria {
  const Categoria(this.nombre, this.icono);
  final String nombre;
  final IconData icono;
}

const categoriasGasto = [
  Categoria('Alimentación', Icons.restaurant_rounded),
  Categoria('Transporte', Icons.directions_car_rounded),
  Categoria('Vivienda', Icons.home_rounded),
  Categoria('Servicios', Icons.bolt_rounded),
  Categoria('Salud', Icons.local_hospital_rounded),
  Categoria('Ocio', Icons.movie_rounded),
  Categoria('Compras', Icons.shopping_bag_rounded),
  Categoria('Educación', Icons.school_rounded),
  Categoria('Otro', Icons.category_rounded),
];

const categoriasIngreso = [
  Categoria('Nómina', Icons.work_rounded),
  Categoria('Ventas', Icons.storefront_rounded),
  Categoria('Regalo', Icons.card_giftcard_rounded),
  Categoria('Inversión', Icons.trending_up_rounded),
  Categoria('Otro', Icons.category_rounded),
];

IconData iconoParaCategoria(String nombre) {
  final todas = [...categoriasGasto, ...categoriasIngreso];
  return todas.firstWhere(
    (c) => c.nombre == nombre,
    orElse: () => const Categoria('Otro', Icons.category_rounded),
  ).icono;
}
