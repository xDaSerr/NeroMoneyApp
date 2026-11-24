import 'package:cloud_firestore/cloud_firestore.dart';

import '../../transactions/data/categoria.dart';
import '../../transactions/data/transaccion.dart';
import '../../transactions/data/transacciones_repository.dart';
import 'apunte_libreta.dart';

/// Préstamos de la Libreta. Cuando un préstamo o un pago mueve una cuenta,
/// el movimiento y el apunte se guardan en la misma transacción de
/// Firestore: el saldo de la cuenta nunca queda desfasado del préstamo.
class LibretaRepository {
  LibretaRepository(this._db, this._uid, this._transacciones);

  final FirebaseFirestore _db;
  final String _uid;
  final TransaccionesRepository _transacciones;

  CollectionReference<Map<String, dynamic>> get _libreta =>
      _db.collection('usuarios').doc(_uid).collection('libreta');

  Stream<List<ApunteLibreta>> observar() => _libreta
      .orderBy('fecha', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ApunteLibreta.fromFirestore).toList());

  /// Guarda un préstamo nuevo. Si tiene cuenta, también registra el dinero
  /// que salió (yo presté) o entró (me prestaron). Puede lanzar
  /// [SaldoInsuficienteException] si la cuenta no alcanza.
  Future<void> crear(ApunteLibreta apunte) async {
    final ref = _libreta.doc();
    final cuentaId = apunte.cuentaId;
    if (cuentaId == null) {
      await ref.set(apunte.toFirestore());
      return;
    }
    await _transacciones.registrarTransaccion(
      Transaccion(
        id: '',
        monto: apunte.monto,
        tipo: apunte.meDeben ? TipoTransaccion.gasto : TipoTransaccion.ingreso,
        categoria: categoriaPrestamo,
        descripcion: apunte.meDeben
            ? 'Préstamo a ${apunte.persona}'
            : 'Préstamo de ${apunte.persona}',
        cuentaId: cuentaId,
        fecha: apunte.fecha,
        libretaId: ref.id,
      ),
      tambien: (tx) => tx.set(ref, apunte.toFirestore()),
    );
  }

  /// Registra un pago (completo o una parte). Nunca más de lo que falta.
  /// Si me deben, el dinero entra a [cuentaId]; si debo, sale de ella.
  Future<void> registrarPago(
    ApunteLibreta apunte, {
    required double monto,
    required DateTime fecha,
    String? cuentaId,
  }) async {
    final aplicado = monto > apunte.pendiente ? apunte.pendiente : monto;
    if (aplicado <= 0) return;
    final ref = _libreta.doc(apunte.id);
    final pago = PagoLibreta(monto: aplicado, fecha: fecha, cuentaId: cuentaId);
    void guardarPago(Transaction tx) => tx.update(ref, {
      'pagos': FieldValue.arrayUnion([pago.toMap()]),
    });
    if (cuentaId == null) {
      await _db.runTransaction((tx) async => guardarPago(tx));
      return;
    }
    await _transacciones.registrarTransaccion(
      Transaccion(
        id: '',
        monto: aplicado,
        tipo: apunte.meDeben ? TipoTransaccion.ingreso : TipoTransaccion.gasto,
        categoria: categoriaPrestamo,
        descripcion: apunte.meDeben
            ? '${apunte.persona} te pagó'
            : 'Pago a ${apunte.persona}',
        cuentaId: cuentaId,
        fecha: fecha,
        libretaId: apunte.id,
      ),
      tambien: guardarPago,
    );
  }

  /// Cambia los datos que no mueven dinero: contacto, promesa y nota.
  Future<void> actualizarDatos(
    String id, {
    required String persona,
    required String telefono,
    required DateTime? fechaPromesa,
    required String nota,
  }) => _libreta.doc(id).update({
    'persona': persona,
    'telefono': telefono,
    'fechaPromesa': fechaPromesa == null
        ? null
        : Timestamp.fromDate(fechaPromesa),
    'nota': nota,
  });

  /// Borra el apunte. Los movimientos que generó se quedan en Movimientos
  /// (ahí se pueden borrar uno por uno, revirtiendo el saldo).
  Future<void> eliminar(String id) => _libreta.doc(id).delete();
}
