import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/moneda/monedas_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../transactions/providers/transacciones_providers.dart';
import '../data/deteccion.dart';
import '../data/resumen_mensual.dart';

final resumenRepositoryProvider = Provider<ResumenRepository>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('resumenRepositoryProvider usado sin sesión activa');
  }
  return ResumenRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instance,
    uid,
  );
});

/// El resumen guardado de un mes ("2026-11"), o null si no se ha pedido.
final resumenMensualProvider = StreamProvider.autoDispose
    .family<ResumenMensual?, String>(
      (ref, mes) => ref.watch(resumenRepositoryProvider).observar(mes),
    );

/// Cargos recurrentes y gastos hormiga de los últimos meses.
final deteccionProvider = Provider.autoDispose<AsyncValue<Deteccion>>((ref) {
  ref.watch(conversorMonedaProvider);
  final ahora = DateTime.now();
  final movimientos = ref.watch(
    transaccionesPorRangoProvider(Deteccion.rango(ahora)),
  );
  return movimientos.whenData((lista) => Deteccion.analizar(lista, ahora));
});
