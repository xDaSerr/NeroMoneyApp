import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// El resumen que Lucy escribió de un mes (functions/resumen.js). Lo
/// guarda el servidor en /resumenesIA/{uid}/meses/{mes}.
class ResumenMensual {
  const ResumenMensual({
    required this.mes,
    this.titular = '',
    this.puntos = const [],
    this.consejo = '',
    this.sinDatos = false,
    this.generadoDia = '',
    this.mesCerrado = false,
  });

  final String mes;
  final String titular;
  final List<String> puntos;
  final String consejo;
  final bool sinDatos;

  /// "2026-11-13": se puede volver a generar una vez al día.
  final String generadoDia;

  /// Se generó después de que terminó el mes: ya no cambia.
  final bool mesCerrado;

  bool get actualizadoHoy => generadoDia == claveDia(DateTime.now());
  bool get puedeActualizar => !actualizadoHoy && !mesCerrado;

  factory ResumenMensual.desdeMapa(Map<String, dynamic> data) => ResumenMensual(
    mes: data['mes'] as String? ?? '',
    titular: data['titular'] as String? ?? '',
    puntos: [
      for (final p in (data['puntos'] as List?) ?? const [])
        if (p is String) p,
    ],
    consejo: data['consejo'] as String? ?? '',
    sinDatos: data['sinDatos'] == true,
    generadoDia: data['generadoDia'] as String? ?? '',
    mesCerrado: data['mesCerrado'] == true,
  );
}

String claveDia(DateTime f) =>
    '${f.year}-${f.month.toString().padLeft(2, '0')}-'
    '${f.day.toString().padLeft(2, '0')}';

/// "2026-11" de una fecha.
String claveMes(DateTime f) =>
    '${f.year}-${f.month.toString().padLeft(2, '0')}';

class ResumenRepository {
  ResumenRepository(this._db, this._functions, this._uid);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final String _uid;

  Stream<ResumenMensual?> observar(String mes) => _db
      .collection('resumenesIA')
      .doc(_uid)
      .collection('meses')
      .doc(mes)
      .snapshots()
      .map(
        (s) => s.data() == null ? null : ResumenMensual.desdeMapa(s.data()!),
      );

  /// Pide al servidor que lo escriba (o devuelve el de hoy si ya existe).
  Future<void> generar(String mes) =>
      _functions.httpsCallable('resumenMensualIA').call({'mes': mes});
}
