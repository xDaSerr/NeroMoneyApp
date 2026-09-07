import 'package:cloud_firestore/cloud_firestore.dart';
import 'perfil_usuario.dart';

class PerfilRepository {
  PerfilRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('usuarios').doc(_uid);

  Stream<PerfilUsuario> observarPerfil() {
    return _doc.snapshots().map(PerfilUsuario.fromFirestore);
  }

  Future<PerfilUsuario> obtenerPerfil() async {
    return PerfilUsuario.fromFirestore(await _doc.get());
  }

  Future<void> guardarPerfil(PerfilUsuario perfil) {
    // merge:true para no pisar otros campos que puedan existir a futuro.
    return _doc.set(perfil.toFirestore(), SetOptions(merge: true));
  }
}
