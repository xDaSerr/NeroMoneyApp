import 'package:cloud_firestore/cloud_firestore.dart';

import 'planeacion.dart';

/// Presupuestos y metas de ahorro del usuario.
class PlaneacionRepository {
  PlaneacionRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _presupuestos =>
      _db.collection('usuarios').doc(_uid).collection('presupuestos');
  CollectionReference<Map<String, dynamic>> get _metas =>
      _db.collection('usuarios').doc(_uid).collection('metas');

  Stream<List<Presupuesto>> observarPresupuestos() => _presupuestos
      .orderBy('categoria')
      .snapshots()
      .map((s) => s.docs.map(Presupuesto.fromFirestore).toList());

  Future<void> guardarPresupuesto(String? id, String categoria, double limite) {
    final datos = {'categoria': categoria, 'limite': limite};
    return id == null
        ? _presupuestos.add(datos)
        : _presupuestos.doc(id).set(datos);
  }

  Future<void> eliminarPresupuesto(String id) => _presupuestos.doc(id).delete();

  Stream<List<MetaAhorro>> observarMetas() => _metas
      .orderBy('creada')
      .snapshots()
      .map((s) => s.docs.map(MetaAhorro.fromFirestore).toList());

  Future<void> guardarMeta(MetaAhorro meta) => meta.id.isEmpty
      ? _metas.add(meta.toFirestore())
      : _metas.doc(meta.id).set(meta.toFirestore());

  /// Suma (o resta, con monto negativo) a lo ahorrado sin pisar otro abono
  /// hecho al mismo tiempo desde otro dispositivo.
  Future<void> abonar(String metaId, double monto) =>
      _metas.doc(metaId).update({'ahorrado': FieldValue.increment(monto)});

  Future<void> eliminarMeta(String id) => _metas.doc(id).delete();
}
