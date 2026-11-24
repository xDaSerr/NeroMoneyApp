import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/moneda/conversor_moneda.dart';

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
    this.sinHora = false,
    this.libretaId,
  });

  /// Dinero que salió o entró por un préstamo de la Libreta (prestar,
  /// pedir prestado o un pago de ellos). Mueve el saldo de la cuenta, pero
  /// no es consumo ni ingreso real.
  final String? libretaId;

  /// Transferencias y préstamos: cambian saldos, pero no cuentan como gasto
  /// ni ingreso en resúmenes, reportes, presupuestos ni análisis.
  bool get esMovimientoInterno => esTransferencia || libretaId != null;

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

  /// Se registró después y no se sabe a qué hora fue (un gasto olvidado):
  /// se guarda al mediodía de ese día y se muestra solo la fecha.
  final bool sinHora;

  /// Hora para mostrar ("14:30"), o null si no se conoce. Los movimientos
  /// viejos con fecha elegida en el calendario quedaron a las 00:00 exactas:
  /// tampoco tienen hora real.
  String? get horaVisible {
    if (sinHora) return null;
    if (fecha.hour == 0 && fecha.minute == 0 && fecha.second == 0) return null;
    return '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
  }

  /// El monto en la moneda principal del perfil (multimoneda, Pro). Todo lo
  /// que SUMA movimientos (gastos del mes, reportes, presupuestos) usa este
  /// valor; lo que muestra UN movimiento usa [monto] con su moneda.
  double get montoPrincipal => ConversorMoneda.deCuenta(monto, cuentaId);

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
      sinHora: data['sinHora'] == true,
      libretaId: data['libretaId'] as String?,
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
      if (sinHora) 'sinHora': true,
      if (libretaId != null) 'libretaId': libretaId,
    };
  }

  /// El efecto de este movimiento sobre `saldoActual`: los gastos restan,
  /// los ingresos suman — igual en todos los tipos de cuenta. En una
  /// tarjeta de crédito `saldoActual` es lo DISPONIBLE de tu línea de
  /// crédito (ver Cuenta.saldoActual), así que un gasto también lo reduce,
  /// tal cual harías con efectivo o débito.
  double get efectoEnSaldo => tipo == TipoTransaccion.ingreso ? monto : -monto;
}
