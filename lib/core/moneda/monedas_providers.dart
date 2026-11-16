import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/accounts/providers/cuentas_providers.dart';
import '../../features/onboarding/providers/perfil_providers.dart';
import 'conversor_moneda.dart';

/// Tipos de cambio (unidades por 1 USD) desde el servidor (functions/
/// monedas.js, que los renueva cada 12 h). Solo se piden si hay alguna
/// cuenta en otra moneda.
final tiposCambioProvider = FutureProvider<Map<String, double>>((ref) async {
  final r = await FirebaseFunctions.instance
      .httpsCallable('tiposDeCambio')
      .call<Map<String, dynamic>>();
  final tasas = (r.data['tasas'] as Map?) ?? const {};
  return {
    for (final e in tasas.entries)
      if (e.value is num) e.key as String: (e.value as num).toDouble(),
  };
});

/// Configura ConversorMoneda con las cuentas, la moneda principal y los
/// tipos de cambio. Las pantallas que suman montos lo vigilan para
/// recalcular cuando cambia algo (ej. llegan las tasas).
final conversorMonedaProvider = Provider<int>((ref) {
  final cuentas = ref.watch(cuentasProvider).value ?? const [];
  final principal = ref.watch(perfilProvider).value?.moneda ?? 'MXN';
  final monedaPorCuenta = {
    for (final c in cuentas)
      if (c.moneda != null && c.moneda != principal) c.id: c.moneda!,
  };
  final tasas = monedaPorCuenta.isEmpty
      ? const <String, double>{}
      : ref.watch(tiposCambioProvider).value ?? const <String, double>{};
  ConversorMoneda.configurar(
    principal: principal,
    monedaPorCuenta: monedaPorCuenta,
    tasas: tasas,
  );
  return Object.hash(
    principal,
    Object.hashAllUnordered(monedaPorCuenta.entries.map((e) => e.toString())),
    tasas.length,
  );
});
