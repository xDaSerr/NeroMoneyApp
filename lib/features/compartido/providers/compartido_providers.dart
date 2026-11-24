import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/compartido_repository.dart';
import '../data/grupo.dart';

final compartidoRepositoryProvider = Provider<CompartidoRepository>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('compartidoRepositoryProvider usado sin sesión activa');
  }
  return CompartidoRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instance,
    uid,
  );
});

final grupoIdProvider = StreamProvider<String?>((ref) {
  return ref.watch(compartidoRepositoryProvider).observarGrupoId();
});

final grupoProvider = StreamProvider<Grupo?>((ref) {
  final id = ref.watch(grupoIdProvider).value;
  if (id == null) return Stream.value(null);
  return ref.watch(compartidoRepositoryProvider).observarGrupo(id);
});

final gastosGrupoProvider = StreamProvider.family<List<GastoCompartido>, String>(
  (ref, grupoId) =>
      ref.watch(compartidoRepositoryProvider).observarGastos(grupoId),
);

final metasGrupoProvider = StreamProvider.family<List<MetaCompartida>, String>(
  (ref, grupoId) =>
      ref.watch(compartidoRepositoryProvider).observarMetas(grupoId),
);
