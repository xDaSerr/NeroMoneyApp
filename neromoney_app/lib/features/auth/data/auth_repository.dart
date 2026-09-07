import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// ID de cliente OAuth "Web" (client_type 3) que Firebase generó para este
/// proyecto al activar Google Sign-In. google_sign_in lo necesita en Android
/// como `serverClientId` para que el idToken resultante tenga la audiencia
/// correcta y Firebase lo acepte al hacer el intercambio de credenciales.
/// Se puede volver a obtener de android/app/google-services.json →
/// "oauth_client" → la entrada con "client_type": 3.
const _googleServerClientId =
    '909698455391-pmv1pmbufo6lcq8eloq651fbnm7i2gln.apps.googleusercontent.com';

/// Envuelve Firebase Auth + Google Sign-In detrás de una API simple. El
/// resto de la app nunca llama a FirebaseAuth ni a GoogleSignIn directamente,
/// solo a este repositorio — así, si mañana cambia el SDK, solo se toca aquí.
class AuthRepository {
  AuthRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;
  bool _googleSignInInitialized = false;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> _ensureGoogleSignInReady() async {
    if (_googleSignInInitialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _googleServerClientId);
    _googleSignInInitialized = true;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Devuelve null si el usuario cancela el diálogo de selección de cuenta
  /// (no se trata como error).
  Future<UserCredential?> signInWithGoogle() async {
    await _ensureGoogleSignInReady();
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      return await _firebaseAuth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    if (_googleSignInInitialized) {
      await GoogleSignIn.instance.signOut();
    }
  }

  /// Traduce los códigos de error de Firebase a mensajes que un usuario
  /// normal entiende, en español.
  static String messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Correo o contraseña incorrectos.';
      case 'invalid-email':
        return 'Ese correo no es válido.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      default:
        return 'Algo salió mal. Inténtalo de nuevo.';
    }
  }
}
