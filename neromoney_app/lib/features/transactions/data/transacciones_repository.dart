import 'package:cloud_firestore/cloud_firestore.dart';

import '../../accounts/data/cuenta.dart';
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

  /// Todos los movimientos entre dos fechas (sin límite de 50 como
  /// `observarTransacciones`) — lo usa Reportes, que necesita ver un mes o
  /// un año completos, no solo los últimos movimientos recientes. Dos
  /// filtros de rango sobre el MISMO campo (`fecha`) no piden un índice
  /// compuesto (a diferencia de `observarPorCuenta`, que combina una
  /// igualdad en `cuentaId` con un orden en `fecha` — campos distintos).
  Stream<List<Transaccion>> observarPorRango(DateTime desde, DateTime hasta) {
    return _coleccion
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThan: Timestamp.fromDate(hasta))
        .snapshots()
        .map((snap) => snap.docs.map(Transaccion.fromFirestore).toList());
  }

  Future<void> registrarTransaccion(Transaccion transaccion) {
    if (transaccion.esTransferencia) {
      throw ArgumentError(
        'Usa registrarTransferencia para actualizar ambas cuentas.',
      );
    }
    final cuentaRef = _usuarioDoc
        .collection('cuentas')
        .doc(transaccion.cuentaId);
    final transaccionRef = _coleccion.doc();

    return _firestore.runTransaction((tx) async {
      final cuentaSnap = await tx.get(cuentaRef);
      final saldoActual =
          (cuentaSnap.data()?['saldoActual'] as num?)?.toDouble() ?? 0;
      final nuevoSaldo = saldoActual + transaccion.efectoEnSaldo;

      // Un ingreso siempre suma, nunca hay problema. Un gasto que dejaría
      // el saldo en negativo es imposible en la vida real (no tienes ese
      // efectivo, o te pasarías del límite de la tarjeta) — se rechaza
      // aquí en vez de guardar un número que no podría existir de verdad.
      // Un margen de un centavo evita falsos positivos por redondeo de
      // punto flotante en un saldo que debería quedar justo en $0.
      if (transaccion.tipo == TipoTransaccion.gasto && nuevoSaldo < -0.01) {
        final nombreCuenta =
            cuentaSnap.data()?['nombre'] as String? ?? 'esta cuenta';
        throw SaldoInsuficienteException(nombreCuenta, saldoActual);
      }

      tx.set(transaccionRef, transaccion.toFirestore());
      tx.update(cuentaRef, {'saldoActual': nuevoSaldo});
    });
  }

  /// El ID se conserva al reintentar, para que una respuesta de red perdida
  /// no provoque una segunda transferencia con los mismos datos.
  String nuevaTransferenciaId() => _coleccion.doc().id;

  Future<void> registrarTransferencia({
    required String id,
    required String cuentaOrigenId,
    required String cuentaDestinoId,
    required double monto,
    required DateTime fecha,
    String nota = '',
  }) {
    if (id.isEmpty ||
        id.contains('/') ||
        cuentaOrigenId.isEmpty ||
        cuentaDestinoId.isEmpty ||
        cuentaOrigenId == cuentaDestinoId) {
      throw ArgumentError('Elige dos cuentas distintas.');
    }
    if (!monto.isFinite ||
        monto <= 0 ||
        monto > 999999999999.99 ||
        (monto * 100).round() == 0 ||
        (monto * 100 - (monto * 100).round()).abs() > 0.001) {
      throw ArgumentError('Escribe un monto positivo con hasta dos decimales.');
    }
    final centavos = (monto * 100).round();
    final salidaRef = _coleccion.doc('${id}_salida');
    final entradaRef = _coleccion.doc('${id}_entrada');
    final origenRef = _usuarioDoc.collection('cuentas').doc(cuentaOrigenId);
    final destinoRef = _usuarioDoc.collection('cuentas').doc(cuentaDestinoId);

    return _firestore.runTransaction((tx) async {
      final salida = await tx.get(salidaRef);
      final entrada = await tx.get(entradaRef);
      if (salida.exists || entrada.exists) {
        if (salida.exists &&
            entrada.exists &&
            salida.data()!['cuentaId'] == cuentaOrigenId &&
            entrada.data()!['cuentaId'] == cuentaDestinoId &&
            salida.data()!['monto'] == centavos / 100 &&
            salida.data()!['descripcion'] == nota.trim()) {
          return;
        }
        throw StateError(
          'Esta operación ya fue registrada con otros datos. Vuelve a Inicio.',
        );
      }
      final origenSnap = await tx.get(origenRef);
      final destinoSnap = await tx.get(destinoRef);
      if (!origenSnap.exists || !destinoSnap.exists) {
        throw StateError(
          'Una de las cuentas ya no existe. Vuelve a elegir las cuentas.',
        );
      }
      final origen = Cuenta.fromFirestore(origenSnap);
      final destino = Cuenta.fromFirestore(destinoSnap);
      if (!origen.permiteTransferencias || !destino.permiteTransferencias) {
        throw StateError(
          'Solo puedes transferir entre cuentas de débito y efectivo.',
        );
      }
      final saldoOrigen = (origen.saldoActual * 100).round();
      final saldoDestino = (destino.saldoActual * 100).round();
      if (centavos > saldoOrigen) {
        throw SaldoInsuficienteException(origen.nombre, origen.saldoActual);
      }
      Transaccion apunte(
        TipoTransaccion tipo,
        String cuenta,
        String contraparte,
      ) => Transaccion(
        id: '',
        monto: centavos / 100,
        tipo: tipo,
        categoria: 'Transferencia',
        cuentaId: cuenta,
        fecha: fecha,
        descripcion: nota.trim(),
        transferenciaId: id,
        cuentaContraparteId: contraparte,
      );
      // Las cuatro escrituras se confirman juntas; nunca queda una sola mitad.
      tx.set(
        salidaRef,
        apunte(
          TipoTransaccion.gasto,
          cuentaOrigenId,
          cuentaDestinoId,
        ).toFirestore(),
      );
      tx.set(
        entradaRef,
        apunte(
          TipoTransaccion.ingreso,
          cuentaDestinoId,
          cuentaOrigenId,
        ).toFirestore(),
      );
      tx.update(origenRef, {'saldoActual': (saldoOrigen - centavos) / 100});
      tx.update(destinoRef, {'saldoActual': (saldoDestino + centavos) / 100});
    });
  }

  Future<void> eliminarTransaccion(Transaccion transaccion) {
    final transaccionRef = _coleccion.doc(transaccion.id);

    return _firestore.runTransaction((tx) async {
      final movimientoSnap = await tx.get(transaccionRef);
      // Otro dispositivo puede haberlo eliminado: nunca revertir dos veces.
      if (!movimientoSnap.exists) return;
      final actual = Transaccion.fromFirestore(movimientoSnap);
      final cuentaRef = _usuarioDoc.collection('cuentas').doc(actual.cuentaId);
      final cuentaSnap = await tx.get(cuentaRef);
      if (!cuentaSnap.exists) {
        throw StateError(
          'La cuenta ya no existe; no se puede revertir el saldo.',
        );
      }
      final saldoActual =
          (cuentaSnap.data()?['saldoActual'] as num?)?.toDouble() ?? 0;

      if (actual.esTransferencia) {
        final esSalida = actual.tipo == TipoTransaccion.gasto;
        final parejaRef = _coleccion.doc(
          '${actual.transferenciaId}_${esSalida ? 'entrada' : 'salida'}',
        );
        final parejaSnap = await tx.get(parejaRef);
        if (!parejaSnap.exists) {
          throw StateError('Falta la otra parte de esta transferencia.');
        }
        final pareja = Transaccion.fromFirestore(parejaSnap);
        if (pareja.transferenciaId != actual.transferenciaId ||
            pareja.cuentaId != actual.cuentaContraparteId ||
            pareja.cuentaContraparteId != actual.cuentaId ||
            pareja.tipo == actual.tipo ||
            pareja.monto != actual.monto) {
          throw StateError('Los datos de la transferencia no coinciden.');
        }
        final parejaCuentaRef = _usuarioDoc
            .collection('cuentas')
            .doc(pareja.cuentaId);
        final parejaCuentaSnap = await tx.get(parejaCuentaRef);
        if (!parejaCuentaSnap.exists) {
          throw StateError(
            'La otra cuenta ya no existe; no se puede revertir la transferencia.',
          );
        }
        final saldoPareja = (parejaCuentaSnap.data()!['saldoActual'] as num)
            .toDouble();
        final nuevoSaldo =
            ((saldoActual * 100).round() -
                (actual.efectoEnSaldo * 100).round()) /
            100;
        final nuevoSaldoPareja =
            ((saldoPareja * 100).round() -
                (pareja.efectoEnSaldo * 100).round()) /
            100;
        if (nuevoSaldo < 0 || nuevoSaldoPareja < 0) {
          throw StateError(
            'La cuenta que recibió el dinero ya no tiene saldo suficiente para deshacer la transferencia.',
          );
        }
        tx.update(cuentaRef, {'saldoActual': nuevoSaldo});
        tx.update(parejaCuentaRef, {'saldoActual': nuevoSaldoPareja});
        tx.delete(transaccionRef);
        tx.delete(parejaRef);
        return;
      }

      tx.delete(transaccionRef);
      // Revierte el efecto que tuvo esta transacción sobre el saldo.
      tx.update(cuentaRef, {'saldoActual': saldoActual - actual.efectoEnSaldo});
    });
  }
}
