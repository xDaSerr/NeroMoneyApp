import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/membresia.dart';
import '../data/planes_repository.dart';

final planesRepositoryProvider = Provider<PlanesRepository>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('planesRepositoryProvider usado sin sesión activa');
  }
  return PlanesRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instance,
    uid,
  );
});

/// Membresía actual, en tiempo real (cambia sola cuando llega el webhook).
final membresiaProvider = StreamProvider<Membresia>((ref) {
  return ref.watch(planesRepositoryProvider).observarMembresia();
});

final usoIAProvider = StreamProvider<UsoIA>((ref) {
  return ref.watch(planesRepositoryProvider).observarUso();
});
