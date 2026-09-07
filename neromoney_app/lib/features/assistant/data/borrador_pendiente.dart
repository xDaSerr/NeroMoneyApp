import 'package:cloud_firestore/cloud_firestore.dart';
import '../../transactions/data/transaccion.dart';

/// Una transacción que Lucy extrajo de un mensaje pero que aún no se puede
/// registrar porque falta un dato — hoy en día, siempre la cuenta de pago
/// (ver "Flujo de IA — slot-filling" en CLAUDE.md).
///
/// Vive en un solo documento fijo (`usuarios/{uid}/estadoAsistente/borrador`)
/// porque solo puede haber un borrador pendiente a la vez — si llega uno
/// nuevo, reemplaza al anterior. Expira solo (`expirado`) para que una
/// pregunta sin responder no bloquee el chat para siempre.
class BorradorPendiente {
  const BorradorPendiente({
    required this.tipo,
    required this.monto,
    required this.categoria,
    required this.descripcion,
    required this.cuentaMencionada,
    required this.creadoEn,
    this.idsCuentasSugeridas = const [],
  });

  final TipoTransaccion tipo;
  final double monto;
  final String categoria;
  final String descripcion;

  /// Lo que el usuario dijo textualmente sobre la forma de pago (puede venir
  /// vacío). Se guarda por si sirve de pista al resolver un mensaje
  /// posterior, aunque hoy no se reintenta automáticamente con esto.
  final String cuentaMencionada;

  final DateTime creadoEn;

  /// Los ids de cuenta que se le mostraron al usuario como chips — se
  /// guardan para poder validar que la cuenta que elija sea una de esas.
  final List<String> idsCuentasSugeridas;

  /// Una pregunta sin responder no debe bloquear el chat para siempre —
  /// pasada una hora, se considera vencida y un mensaje nuevo empieza de cero.
  bool get expirado => DateTime.now().difference(creadoEn) > const Duration(hours: 1);

  factory BorradorPendiente.fromFirestore(Map<String, dynamic> data) {
    return BorradorPendiente(
      tipo: TipoTransaccion.values.byName(data['tipo'] as String),
      monto: (data['monto'] as num).toDouble(),
      categoria: data['categoria'] as String,
      descripcion: data['descripcion'] as String? ?? '',
      cuentaMencionada: data['cuentaMencionada'] as String? ?? '',
      creadoEn: (data['creadoEn'] as Timestamp).toDate(),
      idsCuentasSugeridas:
          (data['idsCuentasSugeridas'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tipo': tipo.name,
      'monto': monto,
      'categoria': categoria,
      'descripcion': descripcion,
      'cuentaMencionada': cuentaMencionada,
      'creadoEn': Timestamp.fromDate(creadoEn),
      'idsCuentasSugeridas': idsCuentasSugeridas,
    };
  }
}
