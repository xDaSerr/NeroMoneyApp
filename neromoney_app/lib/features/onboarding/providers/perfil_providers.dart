import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/perfil_repository.dart';
import '../data/perfil_usuario.dart';

final perfilRepositoryProvider = Provider<PerfilRepository>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('perfilRepositoryProvider usado sin sesión activa');
  }
  return PerfilRepository(FirebaseFirestore.instance, uid);
});

/// Perfil del usuario (moneda, nombre del asistente, estado del onboarding),
/// en tiempo real.
final perfilProvider = StreamProvider<PerfilUsuario>((ref) {
  return ref.watch(perfilRepositoryProvider).observarPerfil();
});
