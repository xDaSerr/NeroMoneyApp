/// false = los botones de pago solo avisan que las suscripciones vienen
/// pronto (Polar sigue en pruebas). Cambiar a true al abrir los cobros.
const suscripcionesAbiertas = false;
const avisoSuscripcionesPendientes =
    'Las suscripciones aún están pendientes, ¡te diremos cuando estén listas!';

/// Las tres membresías de NeroMoney. Los límites reales los aplica el
/// servidor (functions/planes.js); aquí solo se muestran.
enum PlanNero {
  gratis('Gratis', 'Lleva tus gastos a mano.', 0, 0),
  plus('Plus', 'Que Lucy haga el trabajo por ti.', 1.50, 14.99),
  pro('Pro', 'Control total de tu dinero.', 2.99, 29.99);

  const PlanNero(this.nombre, this.lema, this.precioMensual, this.precioAnual);

  final String nombre;
  final String lema;
  final double precioMensual;
  final double precioAnual;

  /// Presupuestos y metas de ahorro: Gratis tiene uno de cada (null = sin
  /// límite).
  int? get maxPresupuestos => this == gratis ? 1 : null;
  int? get maxMetas => this == gratis ? 1 : null;

  static PlanNero desde(String? valor) => switch (valor) {
    'plus' => PlanNero.plus,
    'pro' => PlanNero.pro,
    _ => PlanNero.gratis,
  };
}

/// Lo que el servidor guardó en /suscripciones/{uid} desde el webhook de
/// Polar. Sin documento = Gratis.
class Membresia {
  const Membresia({
    required this.plan,
    this.cancelaAlFinal = false,
    this.periodoFin,
    this.tieneCuentaDePago = false,
  });

  static const gratis = Membresia(plan: PlanNero.gratis);

  final PlanNero plan;

  /// Canceló, pero conserva el plan hasta [periodoFin].
  final bool cancelaAlFinal;
  final DateTime? periodoFin;

  /// Ya pagó alguna vez en Polar: puede abrir el portal (facturas, tarjeta).
  final bool tieneCuentaDePago;

  factory Membresia.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return gratis;
    final plan = PlanNero.desde(data['plan'] as String?);
    final suscripciones = (data['suscripciones'] as Map?) ?? const {};
    // Fecha de corte de la suscripción que da el plan actual.
    bool cancela = false;
    DateTime? fin;
    for (final s in suscripciones.values) {
      if (s is! Map || s['plan'] != plan.name) continue;
      if (!const {'active', 'trialing', 'past_due'}.contains(s['estado'])) {
        continue;
      }
      cancela = s['cancelaAlFinal'] == true;
      fin = DateTime.tryParse(s['periodoFin'] as String? ?? '');
    }
    return Membresia(
      plan: plan,
      cancelaAlFinal: cancela,
      periodoFin: fin,
      tieneCuentaDePago: data['clientePolarId'] != null,
    );
  }
}

/// Mensajes de IA usados (/usoIA/{uid}), para mostrar cuántos quedan en
/// el plan Gratis.
class UsoIA {
  const UsoIA({this.mes, this.enMes = 0});

  final String? mes;
  final int enMes;

  static const limiteGratis = 15;

  /// Mensajes gratis que le quedan este mes (hora de México, como el
  /// servidor; con un día de diferencia en el cambio de mes no pasa nada:
  /// el servidor es quien decide).
  int restantesGratis(DateTime ahora) {
    final mesActual = '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}';
    final usados = mes == mesActual ? enMes : 0;
    return (limiteGratis - usados).clamp(0, limiteGratis);
  }

  factory UsoIA.fromFirestore(Map<String, dynamic>? data) => UsoIA(
    mes: data?['mes'] as String?,
    enMes: (data?['enMes'] as num?)?.toInt() ?? 0,
  );
}
