import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoCuenta { efectivo, debito, credito, vale, otro }

/// Una "cuenta" o bolsillo de dinero (Efectivo, TC de Nu, Vales, etc.).
/// Vive en Firestore bajo `usuarios/{uid}/cuentas/{id}`.
class Cuenta {
  const Cuenta({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.saldoActual,
    this.limiteCredito,
    this.diaCorte,
    this.diaLimitePago,
    this.esPredeterminada = false,
    this.ultimos4Digitos,
    this.colorPersonalizado,
  });

  final String id;
  final String nombre;
  final TipoCuenta tipo;

  bool get permiteTransferencias =>
      tipo == TipoCuenta.debito || tipo == TipoCuenta.efectivo;

  // OJO: el significado de `saldoActual` depende del tipo de cuenta. En
  // cuentas normales (efectivo/débito/vale/otro) es el dinero que SÍ es
  // tuyo. En una tarjeta de crédito es lo que TE QUEDA DISPONIBLE de tu
  // línea de crédito — no lo que debes — igual que lo muestra la app de tu
  // banco. Elegimos "disponible" y no "deuda" a propósito: así un gasto
  // siempre resta y un ingreso siempre suma, sin importar el tipo de
  // cuenta (ver Transaccion.efectoEnSaldo). La deuda real se calcula sola,
  // nunca se guarda directamente — ver `deudaActual` abajo.
  final double saldoActual;

  // Para tipo == credito, ambos son obligatorios: sin límite, "disponible"
  // no significa nada (no se puede calcular la deuda real). diaCorte y
  // diaLimitePago siguen siendo 100% opcionales — solo datos de referencia
  // que el usuario puede anotar si quiere; la app nunca los usa para
  // calcular ni recordar nada (NeroMoney no busca ser el banco, ver
  // CLAUDE.md → "Filosofía sobre tarjetas de crédito").
  final double? limiteCredito;
  final int? diaCorte; // día del mes, 1-31
  final int? diaLimitePago;

  final bool esPredeterminada;

  // Puramente informativos, nunca obligatorios (a diferencia de
  // limiteCredito, que sí es obligatorio para crédito). Sirven para cuando
  // un mismo banco te da una tarjeta física y otra digital — los últimos 4
  // dígitos son la única forma práctica de diferenciarlas a simple vista.
  final String? ultimos4Digitos;

  /// Color elegido por el usuario para esta cuenta (ARGB, `Color.value`).
  /// Si es null, `CuentaTile` usa el color por defecto según el tipo
  /// (violeta para crédito, vidrio normal para el resto).
  final int? colorPersonalizado;

  /// La deuda real de una tarjeta de crédito (límite menos lo disponible).
  /// Null si no es una cuenta de crédito. Este número NO se guarda en
  /// Firestore — se recalcula siempre a partir de `saldoActual` y
  /// `limiteCredito`, que es lo único que el usuario edita a mano cuando
  /// paga la tarjeta o le suben el límite (ver AccountsScreen → "Editar").
  double? get deudaActual =>
      tipo == TipoCuenta.credito ? (limiteCredito ?? 0) - saldoActual : null;

  /// Cómo debe contarse esta cuenta al sumar el patrimonio total: una
  /// tarjeta de crédito NUNCA entra en esa suma — ni sumando lo disponible
  /// (es línea del banco, no tuyo) ni restando la deuda. El patrimonio
  /// total es solo tu dinero real (efectivo/débito/vale/otro); la deuda de
  /// una tarjeta se muestra aparte, en su propia tarjeta (`CuentaTile`),
  /// como algo informativo para dar seguimiento — nunca mezclado en el
  /// número principal. (Decisión explícita del usuario: NeroMoney no
  /// calcula "patrimonio neto" al estilo banco, solo cuánto dinero propio
  /// tienes disponible.)
  double get efectoEnPatrimonio => tipo == TipoCuenta.credito ? 0 : saldoActual;

  /// Días que faltan para la próxima fecha de corte (null si no se
  /// configuró `diaCorte`). Si el día de corte de este mes ya pasó, calcula
  /// el del mes siguiente en vez de dar un número negativo.
  int? get diasParaCorte {
    final dia = diaCorte;
    if (dia == null) return null;
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    var proximoCorte = DateTime(hoy.year, hoy.month, dia);
    if (!proximoCorte.isAfter(hoySinHora)) {
      proximoCorte = DateTime(hoy.year, hoy.month + 1, dia);
    }
    return proximoCorte.difference(hoySinHora).inDays;
  }

  factory Cuenta.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Cuenta(
      id: doc.id,
      nombre: data['nombre'] as String,
      tipo: TipoCuenta.values.byName(data['tipo'] as String),
      saldoActual: (data['saldoActual'] as num).toDouble(),
      limiteCredito: (data['limiteCredito'] as num?)?.toDouble(),
      diaCorte: data['diaCorte'] as int?,
      diaLimitePago: data['diaLimitePago'] as int?,
      esPredeterminada: data['esPredeterminada'] as bool? ?? false,
      ultimos4Digitos: data['ultimos4Digitos'] as String?,
      colorPersonalizado: data['colorPersonalizado'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'tipo': tipo.name,
      'saldoActual': saldoActual,
      if (limiteCredito != null) 'limiteCredito': limiteCredito,
      if (diaCorte != null) 'diaCorte': diaCorte,
      if (diaLimitePago != null) 'diaLimitePago': diaLimitePago,
      'esPredeterminada': esPredeterminada,
      if (ultimos4Digitos != null) 'ultimos4Digitos': ultimos4Digitos,
      if (colorPersonalizado != null) 'colorPersonalizado': colorPersonalizado,
    };
  }

  Cuenta copyWith({
    String? nombre,
    TipoCuenta? tipo,
    double? saldoActual,
    double? limiteCredito,
    int? diaCorte,
    int? diaLimitePago,
    bool? esPredeterminada,
    // Los dos siguientes usan un "envoltorio" (Value) en vez de null directo
    // porque aquí null es un valor válido a propósito (ej. "quita los
    // últimos 4 dígitos que ya había puesto") — con el patrón normal de
    // copyWith (`x ?? this.x`) sería imposible volver a poner algo en null.
    Object? ultimos4Digitos = _sinCambio,
    Object? colorPersonalizado = _sinCambio,
  }) {
    return Cuenta(
      id: id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      saldoActual: saldoActual ?? this.saldoActual,
      limiteCredito: limiteCredito ?? this.limiteCredito,
      diaCorte: diaCorte ?? this.diaCorte,
      diaLimitePago: diaLimitePago ?? this.diaLimitePago,
      esPredeterminada: esPredeterminada ?? this.esPredeterminada,
      ultimos4Digitos: identical(ultimos4Digitos, _sinCambio)
          ? this.ultimos4Digitos
          : ultimos4Digitos as String?,
      colorPersonalizado: identical(colorPersonalizado, _sinCambio)
          ? this.colorPersonalizado
          : colorPersonalizado as int?,
    );
  }
}

// Centinela para distinguir "no lo toques" de "ponlo en null a propósito"
// en copyWith — ver el comentario junto a los parámetros que lo usan.
const _sinCambio = Object();

extension TipoCuentaLabel on TipoCuenta {
  String get etiqueta => switch (this) {
    TipoCuenta.efectivo => 'Efectivo',
    TipoCuenta.debito => 'Débito',
    TipoCuenta.credito => 'Crédito',
    TipoCuenta.vale => 'Vale',
    TipoCuenta.otro => 'Otro',
  };
}
