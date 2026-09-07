import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(FirebaseAuth.instance);
});

/// Emite el usuario actual cada vez que cambia la sesión (login/logout).
/// El router lo usa para decidir a qué pantalla mandarte.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// El uid del usuario actual, listo para usarse sin esperar al primer
/// evento del stream. `authStateChangesProvider` tarda un tick en emitir su
/// primer valor (StreamProvider arranca en `loading`), así que si algo lo
/// necesita ANTES de eso (ej. justo al crear un repositorio), `.value`
/// puede salir null aunque Firebase ya tenga la sesión lista. Por eso aquí
/// se cae de respaldo a `FirebaseAuth.instance.currentUser`, que es
/// síncrono, y de paso este provider sigue reaccionando a login/logout
/// porque también observa el stream.
final currentUidProvider = Provider<String?>((ref) {
  final usuarioDelStream = ref.watch(authStateChangesProvider).value;
  return usuarioDelStream?.uid ?? FirebaseAuth.instance.currentUser?.uid;
});
