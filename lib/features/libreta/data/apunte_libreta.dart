import 'package:cloud_firestore/cloud_firestore.dart';

/// Quién le prestó a quién.
enum DireccionPrestamo {
  /// Yo presté: me deben.
  yoPresto,

  /// Me prestaron: debo.
  mePrestan,
}

/// Un pago de un préstamo (puede pagarse en partes).
class PagoLibreta {
  const PagoLibreta({required this.monto, required this.fecha, this.cuentaId});

  final double monto;
  final DateTime fecha;

  /// Cuenta donde entró (o de donde salió) el pago; null = no movió cuentas.
  final String? cuentaId;

  factory PagoLibreta.fromMap(Map<String, dynamic> m) => PagoLibreta(
    monto: (m['monto'] as num).toDouble(),
    fecha: (m['fecha'] as Timestamp).toDate(),
    cuentaId: m['cuentaId'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'monto': monto,
    'fecha': Timestamp.fromDate(fecha),
    if (cuentaId != null) 'cuentaId': cuentaId,
  };
}

/// Un apunte de la Libreta: dinero prestado a alguien o que alguien me
/// prestó, con su contacto, la fecha en que prometió pagar y sus pagos.
/// Vive en `usuarios/{uid}/libreta/{id}`.
class ApunteLibreta {
  const ApunteLibreta({
    required this.id,
    required this.direccion,
    required this.persona,
    required this.monto,
    required this.fecha,
    this.telefono = '',
    this.cuentaId,
    this.fechaPromesa,
    this.nota = '',
    this.pagos = const [],
  });

  final String id;
  final DireccionPrestamo direccion;
  final String persona;
  final String telefono;
  final double monto;

  /// De qué cuenta salió el dinero (si yo presté) o a cuál entró (si me
  /// prestaron). null = se apuntó sin mover ninguna cuenta.
  final String? cuentaId;
  final DateTime fecha;

  /// El día en que dijeron que pagarían.
  final DateTime? fechaPromesa;
  final String nota;
  final List<PagoLibreta> pagos;

  bool get meDeben => direccion == DireccionPrestamo.yoPresto;
  double get pagado => pagos.fold(0, (s, p) => s + p.monto);
  double get pendiente {
    final resto = monto - pagado;
    return resto < 0.005 ? 0 : resto;
  }

  bool get liquidado => pendiente <= 0;
  double get progreso => monto <= 0 ? 1 : (pagado / monto).clamp(0.0, 1.0);

  /// Días que faltan para la fecha prometida (negativo = ya pasó). null si
  /// no hay fecha o ya está pagado.
  int? diasParaPromesa(DateTime hoy) {
    if (fechaPromesa == null || liquidado) return null;
    final a = DateTime(hoy.year, hoy.month, hoy.day);
    final b = DateTime(
      fechaPromesa!.year,
      fechaPromesa!.month,
      fechaPromesa!.day,
    );
    return b.difference(a).inDays;
  }

  factory ApunteLibreta.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return ApunteLibreta(
      id: doc.id,
      direccion: d['direccion'] == 'mePrestan'
          ? DireccionPrestamo.mePrestan
          : DireccionPrestamo.yoPresto,
      persona: d['persona'] as String? ?? '',
      telefono: d['telefono'] as String? ?? '',
      monto: (d['monto'] as num?)?.toDouble() ?? 0,
      cuentaId: d['cuentaId'] as String?,
      fecha: (d['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaPromesa: (d['fechaPromesa'] as Timestamp?)?.toDate(),
      nota: d['nota'] as String? ?? '',
      pagos: [
        for (final p in (d['pagos'] as List<dynamic>? ?? const []))
          if (p is Map) PagoLibreta.fromMap(Map<String, dynamic>.from(p)),
      ],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'direccion': direccion.name,
    'persona': persona,
    'telefono': telefono,
    'monto': monto,
    'cuentaId': cuentaId,
    'fecha': Timestamp.fromDate(fecha),
    'fechaPromesa': fechaPromesa == null
        ? null
        : Timestamp.fromDate(fechaPromesa!),
    'nota': nota,
    'pagos': pagos.map((p) => p.toMap()).toList(),
  };
}

/// Totales de la Libreta para el encabezado y la tarjeta de Inicio.
class ResumenLibreta {
  const ResumenLibreta({
    required this.meDeben,
    required this.debo,
    required this.vencidos,
  });

  final double meDeben;
  final double debo;

  /// Préstamos sin pagar cuya fecha prometida ya pasó.
  final int vencidos;

  static ResumenLibreta calcular(List<ApunteLibreta> apuntes, DateTime hoy) {
    var meDeben = 0.0;
    var debo = 0.0;
    var vencidos = 0;
    for (final a in apuntes) {
      if (a.liquidado) continue;
      if (a.meDeben) {
        meDeben += a.pendiente;
      } else {
        debo += a.pendiente;
      }
      final dias = a.diasParaPromesa(hoy);
      if (dias != null && dias < 0) vencidos++;
    }
    return ResumenLibreta(meDeben: meDeben, debo: debo, vencidos: vencidos);
  }
}
