import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'grupo.dart';

/// Gastos compartidos. Crear, unirse y salir van por Cloud Functions (ver
/// functions/compartido.js); gastos y metas se escriben directo en
/// Firestore, protegidos por las reglas (solo miembros).
class CompartidoRepository {
  CompartidoRepository(this._db, this._functions, this._uid);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final String _uid;

  String get uid => _uid;

  /// El grupo del usuario (lo escribe el servidor en su perfil).
  Stream<String?> observarGrupoId() => _db
      .collection('usuarios')
      .doc(_uid)
      .snapshots()
      .map((s) => s.data()?['grupoId'] as String?);

  Stream<Grupo?> observarGrupo(String id) => _db
      .collection('grupos')
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? Grupo.fromFirestore(s) : null);

  CollectionReference<Map<String, dynamic>> _gastos(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('gastos');
  CollectionReference<Map<String, dynamic>> _metas(String grupoId) =>
      _db.collection('grupos').doc(grupoId).collection('metas');

  Stream<List<GastoCompartido>> observarGastos(String grupoId) =>
      _gastos(grupoId)
          .orderBy('fecha', descending: true)
          .limit(300)
          .snapshots()
          .map((s) => s.docs.map(GastoCompartido.fromFirestore).toList());

  Stream<List<MetaCompartida>> observarMetas(String grupoId) => _metas(
    grupoId,
  ).snapshots().map((s) => s.docs.map(MetaCompartida.fromFirestore).toList());

  Future<void> crearGrupo(String nombre, String miNombre) => _functions
      .httpsCallable('crearGrupo')
      .call({'nombre': nombre, 'miNombre': miNombre});

  Future<void> unirse(String codigo, String miNombre) => _functions
      .httpsCallable('unirseAGrupo')
      .call({'codigo': codigo, 'miNombre': miNombre});

  Future<void> salir() => _functions.httpsCallable('salirDeGrupo').call();

  Future<void> agregarGasto(String grupoId, GastoCompartido gasto) =>
      _gastos(grupoId).add(gasto.toFirestore());

  Future<void> eliminarGasto(String grupoId, String id) =>
      _gastos(grupoId).doc(id).delete();

  Future<void> crearMeta(
    String grupoId,
    String nombre,
    double objetivo,
    DateTime? fechaLimite,
  ) => _metas(grupoId).add({
    'nombre': nombre,
    'monto': objetivo,
    'aportes': <String, double>{},
    'fechaLimite': fechaLimite == null ? null : Timestamp.fromDate(fechaLimite),
  });

  /// Suma lo que aporté sin pisar un aporte hecho al mismo tiempo por otro.
  Future<void> aportar(String grupoId, String metaId, double monto) =>
      _metas(grupoId).doc(metaId).update({
        'aportes.$_uid': FieldValue.increment(monto),
      });

  Future<void> eliminarMeta(String grupoId, String id) =>
      _metas(grupoId).doc(id).delete();
}
