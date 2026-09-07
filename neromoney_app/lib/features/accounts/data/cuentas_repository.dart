import 'package:cloud_firestore/cloud_firestore.dart';
import 'cuenta.dart';

/// Todo el acceso a Firestore para las cuentas de un usuario pasa por aquí.
class CuentasRepository {
  CuentasRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _firestore.collection('usuarios').doc(_uid).collection('cuentas');

  Stream<List<Cuenta>> observarCuentas() {
    return _coleccion.orderBy('nombre').snapshots().map(
          (snap) => snap.docs.map(Cuenta.fromFirestore).toList(),
        );
  }

  Future<String> crearCuenta(Cuenta cuenta) async {
    final ref = await _coleccion.add(cuenta.toFirestore());
    return ref.id;
  }

  Future<void> actualizarCuenta(Cuenta cuenta) {
    return _coleccion.doc(cuenta.id).update(cuenta.toFirestore());
  }

  Future<void> eliminarCuenta(String cuentaId) {
    return _coleccion.doc(cuentaId).delete();
  }

  /// Marca `cuentaId` como predeterminada y quita esa marca de las demás
  /// (una sola cuenta predeterminada a la vez). Se usa para que la IA sepa
  /// a qué cuenta asignar un gasto cuando el usuario es ambiguo ("con mi
  /// tarjeta").
  Future<void> marcarComoPredeterminada(String cuentaId) async {
    final snap = await _coleccion.get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'esPredeterminada': doc.id == cuentaId});
    }
    await batch.commit();
  }
}
