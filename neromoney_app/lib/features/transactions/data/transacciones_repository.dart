import 'package:cloud_firestore/cloud_firestore.dart';
import 'transaccion.dart';

/// Se lanza cuando un gasto dejaría `saldoActual` en negativo. Aplica igual
/// a cualquier tipo de cuenta: en efectivo/débito/vale/otro significaría
/// gastar dinero que no tienes, y en una tarjeta de crédito significaría
/// pasarte del límite — algo que el banco real rechazaría en el momento de
/// pagar. Nunca se llega a escribir nada en Firestore: al lanzarse dentro
/// de `runTransaction`, esa transacción se cancela sola.
class SaldoInsuficienteException implements Exception {
  const SaldoInsuficienteException(this.nombreCuenta, this.disponible);

  final String nombreCuenta;
  final double disponible;

  @override
  String toString() =>
      '"$nombreCuenta" no tiene suficiente saldo disponible (\$${disponible.toStringAsFixed(2)}).';
}

/// Acceso a Firestore para los movimientos. Cada alta/edición/borrado de un
/// movimiento también ajusta el saldo de su cuenta — usamos
/// `runTransaction` para que ambas escrituras sean atómicas (o se aplican
/// las dos, o ninguna; así el saldo nunca queda desincronizado).
class TransaccionesRepository {
  TransaccionesRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _usuarioDoc =>
      _firestore.collection('usuarios').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _usuarioDoc.collection('transacciones');

  Stream<List<Transaccion>> observarTransacciones({int limite = 50}) {
    return _coleccion
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map((snap) => snap.docs.map(Transaccion.fromFirestore).toList());
  }

  Stream<List<Transaccion>> observarPorCuenta(String cuentaId) {
    return _coleccion
        .where('cuentaId', isEqualTo: cuentaId)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Transaccion.fromFirestore).toList());
  }

  Future<void> registrarTransaccion(Transaccion transaccion) {
    final cuentaRef = _usuarioDoc.collection('cuentas').doc(transaccion.cuentaId);
    final transaccionRef = _coleccion.doc();

    return _firestore.runTransaction((tx) async {
      final cuentaSnap = await tx.get(cuentaRef);
      final saldoActual = (cuentaSnap.data()?['saldoActual'] as num?)?.toDouble() ?? 0;
      final nuevoSaldo = saldoActual + transaccion.efectoEnSaldo;

      // Un ingreso siempre suma, nunca hay problema. Un gasto que dejaría
      // el saldo en negativo es imposible en la vida real (no tienes ese
      // efectivo, o te pasarías del límite de la tarjeta) — se rechaza
      // aquí en vez de guardar un número que no podría existir de verdad.
      // Un margen de un centavo evita falsos positivos por redondeo de
      // punto flotante en un saldo que debería quedar justo en $0.
      if (transaccion.tipo == TipoTransaccion.gasto && nuevoSaldo < -0.01) {
        final nombreCuenta = cuentaSnap.data()?['nombre'] as String? ?? 'esta cuenta';
        throw SaldoInsuficienteException(nombreCuenta, saldoActual);
      }

      tx.set(transaccionRef, transaccion.toFirestore());
      tx.update(cuentaRef, {'saldoActual': nuevoSaldo});
    });
  }

  Future<void> eliminarTransaccion(Transaccion transaccion) {
    final cuentaRef = _usuarioDoc.collection('cuentas').doc(transaccion.cuentaId);
    final transaccionRef = _coleccion.doc(transaccion.id);

    return _firestore.runTransaction((tx) async {
      final cuentaSnap = await tx.get(cuentaRef);
      final saldoActual = (cuentaSnap.data()?['saldoActual'] as num?)?.toDouble() ?? 0;

      tx.delete(transaccionRef);
      // Revierte el efecto que tuvo esta transacción sobre el saldo.
      tx.update(cuentaRef, {'saldoActual': saldoActual - transaccion.efectoEnSaldo});
    });
  }
}
