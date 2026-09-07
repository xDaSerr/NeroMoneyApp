import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/cuenta.dart';
import '../data/cuentas_repository.dart';

final cuentasRepositoryProvider = Provider<CuentasRepository>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('cuentasRepositoryProvider usado sin sesión activa');
  }
  return CuentasRepository(FirebaseFirestore.instance, uid);
});

/// Lista de cuentas del usuario, actualizada en tiempo real.
final cuentasProvider = StreamProvider<List<Cuenta>>((ref) {
  return ref.watch(cuentasRepositoryProvider).observarCuentas();
});
