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
  // Cuando Lucy corrige un saldo hacia ABAJO (ver AsistenteRepository.
  // _actualizarSaldoCuenta) — nunca un gasto real, por eso lleva su propia
  // categoría en vez de mezclarse con "Otro".
  Categoria('Ajuste', Icons.tune_rounded),
  Categoria('Otro', Icons.category_rounded),
];

const categoriasIngreso = [
  Categoria('Nómina', Icons.work_rounded),
  Categoria('Ventas', Icons.storefront_rounded),
  Categoria('Regalo', Icons.card_giftcard_rounded),
  Categoria('Inversión', Icons.trending_up_rounded),
  // Cuando Lucy corrige un saldo hacia ARRIBA (ver AsistenteRepository.
  // _actualizarSaldoCuenta).
  Categoria('Ajuste', Icons.tune_rounded),
  // Un pago/abono a una tarjeta de crédito (ver AsistenteRepository.
  // _pagarTarjeta) — sube el disponible, así que en el modelo de la app es
  // un ingreso, igual que cualquier otro (ver Transaccion.efectoEnSaldo).
  Categoria('Pago de tarjeta', Icons.credit_score_rounded),
  Categoria('Otro', Icons.category_rounded),
];

IconData iconoParaCategoria(String nombre) {
  final todas = [...categoriasGasto, ...categoriasIngreso];
  return todas.firstWhere(
    (c) => c.nombre == nombre,
    orElse: () => const Categoria('Otro', Icons.category_rounded),
  ).icono;
}
