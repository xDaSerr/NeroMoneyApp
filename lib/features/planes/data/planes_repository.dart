import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'membresia.dart';

/// Lee la membresía (solo lectura: la escribe el servidor) y pide al
/// servidor las páginas de pago y del portal de Polar.
class PlanesRepository {
  PlanesRepository(this._db, this._functions, this._uid);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final String _uid;

  Stream<Membresia> observarMembresia() => _db
      .collection('suscripciones')
      .doc(_uid)
      .snapshots()
      .map((s) => Membresia.fromFirestore(s.data()));

  Stream<UsoIA> observarUso() => _db
      .collection('usoIA')
      .doc(_uid)
      .snapshots()
      .map((s) => UsoIA.fromFirestore(s.data()));

  /// URL de la página de pago de Polar para [plan].
  Future<String> crearCheckout(PlanNero plan, {required bool anual}) async {
    final r = await _functions.httpsCallable('crearCheckoutPolar').call({
      'plan': plan.name,
      'periodo': anual ? 'anual' : 'mensual',
      'origen': _origen,
    });
    return (r.data as Map)['url'] as String;
  }

  /// URL del portal de Polar (cambiar de plan, tarjeta, cancelar).
  Future<String> abrirPortal() async {
    final r = await _functions.httpsCallable('abrirPortalPolar').call({
      'origen': _origen,
    });
    return (r.data as Map)['url'] as String;
  }

  /// A dónde regresa Polar al terminar. En el teléfono no hay "origen":
  /// regresa a la web (el servidor solo acepta direcciones de NeroMoney).
  String? get _origen => kIsWeb ? Uri.base.origin : null;
}
