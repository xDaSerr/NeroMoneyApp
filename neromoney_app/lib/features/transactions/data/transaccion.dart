import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoTransaccion { gasto, ingreso }

enum OrigenTransaccion { manual, iaTexto, iaVoz }

/// Un movimiento (gasto o ingreso), ligado siempre a una cuenta específica.
/// Vive en Firestore bajo `usuarios/{uid}/transacciones/{id}`.
class Transaccion {
  const Transaccion({
    required this.id,
    required this.monto,
    required this.tipo,
    required this.categoria,
    required this.cuentaId,
    required this.fecha,
    this.descripcion = '',
    this.origen = OrigenTransaccion.manual,
    this.transferenciaId,
    this.cuentaContraparteId,
  });

  final String id;
  final double monto;
  final TipoTransaccion tipo;
  final String categoria;
  final String descripcion;
  final String cuentaId;
  final DateTime fecha;
  final OrigenTransaccion origen;
  // Dos apuntes enlazados: salida y entrada. No son consumo ni ingreso real.
  final String? transferenciaId;
  final String? cuentaContraparteId;
  bool get esTransferencia => transferenciaId != null;

  factory Transaccion.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return Transaccion(
      id: doc.id,
      monto: (data['monto'] as num).toDouble(),
      tipo: TipoTransaccion.values.byName(data['tipo'] as String),
      categoria: data['categoria'] as String,
      descripcion: data['descripcion'] as String? ?? '',
      cuentaId: data['cuentaId'] as String,
      fecha: (data['fecha'] as Timestamp).toDate(),
      origen: OrigenTransaccion.values.byName(
        data['origen'] as String? ?? 'manual',
      ),
      transferenciaId: data['transferenciaId'] as String?,
      cuentaContraparteId: data['cuentaContraparteId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'monto': monto,
      'tipo': tipo.name,
      'categoria': categoria,
      'descripcion': descripcion,
      'cuentaId': cuentaId,
      'fecha': Timestamp.fromDate(fecha),
      'origen': origen.name,
      if (transferenciaId != null) 'transferenciaId': transferenciaId,
      if (cuentaContraparteId != null)
        'cuentaContraparteId': cuentaContraparteId,
    };
  }

  /// El efecto de este movimiento sobre `saldoActual`: los gastos restan,
  /// los ingresos suman — igual en todos los tipos de cuenta. En una
  /// tarjeta de crédito `saldoActual` es lo DISPONIBLE de tu línea de
  /// crédito (ver Cuenta.saldoActual), así que un gasto también lo reduce,
  /// tal cual harías con efectivo o débito.
  double get efectoEnSaldo => tipo == TipoTransaccion.ingreso ? monto : -monto;
}
