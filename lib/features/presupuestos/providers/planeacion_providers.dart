import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/moneda/monedas_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../transactions/providers/transacciones_providers.dart';
import '../data/planeacion.dart';
import '../data/planeacion_repository.dart';

final planeacionRepositoryProvider = Provider<PlaneacionRepository>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('planeacionRepositoryProvider usado sin sesión activa');
  }
  return PlaneacionRepository(FirebaseFirestore.instance, uid);
});

final presupuestosProvider = StreamProvider<List<Presupuesto>>((ref) {
  return ref.watch(planeacionRepositoryProvider).observarPresupuestos();
});

final metasProvider = StreamProvider<List<MetaAhorro>>((ref) {
  return ref.watch(planeacionRepositoryProvider).observarMetas();
});

/// Rango del mes en curso, para pedir TODOS sus movimientos (el stream
/// general solo trae los últimos 50).
(DateTime, DateTime) rangoMesActual([DateTime? ahora]) {
  final hoy = ahora ?? DateTime.now();
  return (DateTime(hoy.year, hoy.month), DateTime(hoy.year, hoy.month + 1));
}

/// Cada presupuesto con lo que lleva gastado este mes.
final estadosPresupuestoProvider =
    Provider.autoDispose<AsyncValue<List<EstadoPresupuesto>>>((ref) {
      ref.watch(conversorMonedaProvider);
      final presupuestos = ref.watch(presupuestosProvider);
      final movimientos = ref.watch(
        transaccionesPorRangoProvider(rangoMesActual()),
      );
      if (presupuestos.hasError) {
        return AsyncError(presupuestos.error!, presupuestos.stackTrace!);
      }
      final lista = presupuestos.value;
      final delMes = movimientos.value;
      if (lista == null || delMes == null) return const AsyncLoading();
      return AsyncData(
        EstadoPresupuesto.calcular(lista, delMes, DateTime.now()),
      );
    });
