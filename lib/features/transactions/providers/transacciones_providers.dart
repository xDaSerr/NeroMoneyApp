import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/transaccion.dart';
import '../data/transacciones_repository.dart';

final transaccionesRepositoryProvider = Provider<TransaccionesRepository>((
  ref,
) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('transaccionesRepositoryProvider usado sin sesión activa');
  }
  return TransaccionesRepository(FirebaseFirestore.instance, uid);
});

/// Últimos movimientos del usuario, actualizados en tiempo real.
final transaccionesProvider = StreamProvider<List<Transaccion>>((ref) {
  return ref.watch(transaccionesRepositoryProvider).observarTransacciones();
});

/// Movimientos de UNA cuenta en particular — lo usa la pantalla de detalle
/// de cuenta para que el usuario pueda ver solo lo que pasó ahí, sin tener
/// que buscarlo entre todos sus movimientos.
final transaccionesPorCuentaProvider = StreamProvider.autoDispose
    .family<List<Transaccion>, String>((ref, cuentaId) {
      return ref
          .watch(transaccionesRepositoryProvider)
          .observarPorCuenta(cuentaId);
    });

/// Todos los movimientos entre dos fechas (`(desde, hasta)`) — lo usa
/// Reportes. Un record como parámetro de familia funciona porque los
/// records de Dart ya comparan por valor (dos records con las mismas
/// fechas son `==`), así Riverpod no vuelve a pedir el mismo rango dos veces.
final transaccionesPorRangoProvider = StreamProvider.autoDispose
    .family<List<Transaccion>, (DateTime desde, DateTime hasta)>((ref, rango) {
      return ref
          .watch(transaccionesRepositoryProvider)
          .observarPorRango(rango.$1, rango.$2);
    });
