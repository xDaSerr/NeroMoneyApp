import 'package:cloud_firestore/cloud_firestore.dart';

/// Un grupo de gastos compartidos (pareja, familia, roomies). Vive en
/// `grupos/{id}`; solo sus miembros lo ven (firestore.rules) y la lista de
/// miembros solo la cambian las Cloud Functions.
class Grupo {
  const Grupo({
    required this.id,
    required this.nombre,
    required this.creador,
    required this.miembros,
    required this.nombres,
    required this.codigo,
  });

  final String id;
  final String nombre;
  final String creador;
  final List<String> miembros;

  /// uid → nombre con el que se unió. Se conserva aunque alguien salga,
  /// para que sus gastos viejos sigan diciendo quién pagó.
  final Map<String, String> nombres;

  /// Código de invitación de 6 caracteres.
  final String codigo;

  String nombreDe(String uid) => nombres[uid] ?? 'Alguien';

  factory Grupo.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Grupo(
      id: doc.id,
      nombre: d['nombre'] as String? ?? 'Grupo',
      creador: d['creador'] as String? ?? '',
      miembros: (d['miembros'] as List<dynamic>? ?? const []).cast<String>(),
      nombres: Map<String, String>.from(d['nombres'] as Map? ?? const {}),
      codigo: d['codigo'] as String? ?? '',
    );
  }
}

/// Un gasto del grupo: quién lo pagó y entre quiénes se divide (en partes
/// iguales). Un "pago" es cuando alguien le salda a otro lo que le debía.
/// Vive en `grupos/{id}/gastos/{id}`.
class GastoCompartido {
  const GastoCompartido({
    required this.id,
    required this.monto,
    required this.descripcion,
    required this.categoria,
    required this.pagoUid,
    required this.entre,
    required this.fecha,
    this.esPago = false,
  });

  final String id;
  final double monto;
  final String descripcion;
  final String categoria;

  /// Quién puso el dinero.
  final String pagoUid;

  /// Entre quiénes se reparte. En un pago, solo quien lo recibe.
  final List<String> entre;
  final DateTime fecha;
  final bool esPago;

  factory GastoCompartido.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return GastoCompartido(
      id: doc.id,
      monto: (d['monto'] as num?)?.toDouble() ?? 0,
      descripcion: d['descripcion'] as String? ?? '',
      categoria: d['categoria'] as String? ?? 'Otro',
      pagoUid: d['pagoUid'] as String? ?? '',
      entre: (d['entre'] as List<dynamic>? ?? const []).cast<String>(),
      fecha: (d['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      esPago: d['esPago'] == true,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'monto': monto,
    'descripcion': descripcion,
    'categoria': categoria,
    'pagoUid': pagoUid,
    'entre': entre,
    'fecha': Timestamp.fromDate(fecha),
    if (esPago) 'esPago': true,
  };
}

/// Meta de ahorro en común: cada quien aporta y se ve cuánto puso cada uno.
/// Vive en `grupos/{id}/metas/{id}`.
class MetaCompartida {
  const MetaCompartida({
    required this.id,
    required this.nombre,
    required this.objetivo,
    required this.aportes,
    this.fechaLimite,
  });

  final String id;
  final String nombre;
  final double objetivo;

  /// uid → total aportado.
  final Map<String, double> aportes;
  final DateTime? fechaLimite;

  double get juntado => aportes.values.fold(0, (s, v) => s + v);
  double get progreso =>
      objetivo <= 0 ? 0 : (juntado / objetivo).clamp(0.0, 1.0);
  bool get completada => juntado >= objetivo;

  factory MetaCompartida.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return MetaCompartida(
      id: doc.id,
      nombre: d['nombre'] as String? ?? 'Meta',
      objetivo: (d['monto'] as num?)?.toDouble() ?? 0,
      aportes: {
        for (final e in (d['aportes'] as Map? ?? const {}).entries)
          e.key as String: (e.value as num).toDouble(),
      },
      fechaLimite: (d['fechaLimite'] as Timestamp?)?.toDate(),
    );
  }
}

/// Una deuda para quedar a mano: [de] le paga [monto] a [para].
class Deuda {
  const Deuda(this.de, this.para, this.monto);
  final String de;
  final String para;
  final double monto;
}

/// Cuánto puso y cuánto le toca a cada quien, y quién le debe a quién.
class BalanceGrupo {
  const BalanceGrupo({required this.neto, required this.deudas});

  /// uid → positivo: le deben; negativo: debe.
  final Map<String, double> neto;

  /// La menor cantidad de pagos para quedar todos a mano.
  final List<Deuda> deudas;

  static BalanceGrupo calcular(List<GastoCompartido> gastos) {
    final neto = <String, double>{};
    for (final g in gastos) {
      if (g.entre.isEmpty || g.monto <= 0) continue;
      neto.update(g.pagoUid, (v) => v + g.monto, ifAbsent: () => g.monto);
      final parte = g.monto / g.entre.length;
      for (final u in g.entre) {
        neto.update(u, (v) => v - parte, ifAbsent: () => -parte);
      }
    }
    // Centavos: lo que redondea a cero no es deuda.
    final redondeado = {
      for (final e in neto.entries) e.key: (e.value * 100).round() / 100,
    };

    // Empareja al que más debe con al que más le deben, hasta acabar.
    final acreedores = [
      for (final e in redondeado.entries)
        if (e.value > 0.009) [e.key, e.value],
    ]..sort((a, b) => (b[1] as double).compareTo(a[1] as double));
    final deudores = [
      for (final e in redondeado.entries)
        if (e.value < -0.009) [e.key, -e.value],
    ]..sort((a, b) => (b[1] as double).compareTo(a[1] as double));
    final deudas = <Deuda>[];
    var i = 0;
    var j = 0;
    while (i < deudores.length && j < acreedores.length) {
      final debe = deudores[i][1] as double;
      final leDeben = acreedores[j][1] as double;
      final monto = debe < leDeben ? debe : leDeben;
      deudas.add(
        Deuda(
          deudores[i][0] as String,
          acreedores[j][0] as String,
          (monto * 100).round() / 100,
        ),
      );
      deudores[i][1] = debe - monto;
      acreedores[j][1] = leDeben - monto;
      if ((deudores[i][1] as double) < 0.009) i++;
      if ((acreedores[j][1] as double) < 0.009) j++;
    }
    return BalanceGrupo(neto: redondeado, deudas: deudas);
  }
}
