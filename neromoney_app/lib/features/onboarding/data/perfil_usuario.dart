import 'package:cloud_firestore/cloud_firestore.dart';

/// Config general del usuario: moneda elegida, nombre de su asistente IA, y
/// si ya terminó el onboarding inicial. Vive en `usuarios/{uid}` (el
/// documento raíz, junto a las subcolecciones de cuentas/transacciones).
class PerfilUsuario {
  const PerfilUsuario({
    required this.moneda,
    required this.nombreAsistente,
    required this.onboardingCompletado,
  });

  final String moneda; // código ISO: "MXN", "USD", etc.
  final String nombreAsistente;
  final bool onboardingCompletado;

  static const vacio = PerfilUsuario(
    moneda: 'MXN',
    nombreAsistente: 'Lucy',
    onboardingCompletado: false,
  );

  factory PerfilUsuario.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) return vacio;
    final data = doc.data()!;
    return PerfilUsuario(
      moneda: data['moneda'] as String? ?? vacio.moneda,
      nombreAsistente: data['nombreAsistente'] as String? ?? vacio.nombreAsistente,
      onboardingCompletado: data['onboardingCompletado'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'moneda': moneda,
      'nombreAsistente': nombreAsistente,
      'onboardingCompletado': onboardingCompletado,
    };
  }

  PerfilUsuario copyWith({
    String? moneda,
    String? nombreAsistente,
    bool? onboardingCompletado,
  }) {
    return PerfilUsuario(
      moneda: moneda ?? this.moneda,
      nombreAsistente: nombreAsistente ?? this.nombreAsistente,
      onboardingCompletado: onboardingCompletado ?? this.onboardingCompletado,
    );
  }
}
