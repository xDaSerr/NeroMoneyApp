import 'package:cloud_firestore/cloud_firestore.dart';

/// Config general del usuario: moneda elegida, nombre y foto de su
/// asistente IA, y si ya terminó el onboarding inicial. Vive en
/// `usuarios/{uid}` (el documento raíz, junto a las subcolecciones de
/// cuentas/transacciones).
class PerfilUsuario {
  const PerfilUsuario({
    required this.moneda,
    required this.nombreAsistente,
    required this.onboardingCompletado,
    this.avatarAsistenteBase64,
    this.colorAnilloInicio,
    this.colorAnilloFin,
  });

  final String moneda; // código ISO: "MXN", "USD", etc.
  final String nombreAsistente;
  final bool onboardingCompletado;

  // Foto del asistente elegida por el usuario, codificada en Base64 (ya
  // redimensionada/comprimida al elegirla, ver PersonalizarAsistenteScreen)
  // — no se usa Firebase Storage para esto a propósito: es una sola imagen
  // pequeña por usuario, así que guardarla directo en el documento evita
  // depender de un servicio más y de sus propias reglas de seguridad. Si es
  // null, el asistente usa el ícono de la app como cara por defecto (ver
  // AsistenteAvatar) — nunca un ícono genérico de "IA" sin relación con la
  // app.
  final String? avatarAsistenteBase64;

  // Los 2 colores (ARGB, `Color.toARGB32()`) del degradado del anillo
  // alrededor de la cara del asistente (ver AnilloAsistente), elegidos de
  // `paleta_anillos_asistente.dart`. A diferencia de la foto, este par
  // nunca necesita "borrarse de verdad": si el usuario nunca abrió
  // PersonalizarAsistenteScreen, ambos quedan null y el anillo simplemente
  // usa el degradado por defecto (el mismo que había antes de que esto
  // fuera elegible) — por eso sí puede viajar por el copyWith/guardarPerfil
  // normal, sin el patrón de centinela que sí necesita avatarAsistenteBase64.
  final int? colorAnilloInicio;
  final int? colorAnilloFin;

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
      avatarAsistenteBase64: data['avatarAsistenteBase64'] as String?,
      colorAnilloInicio: data['colorAnilloInicio'] as int?,
      colorAnilloFin: data['colorAnilloFin'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'moneda': moneda,
      'nombreAsistente': nombreAsistente,
      'onboardingCompletado': onboardingCompletado,
      // OJO: quitar la foto (volver al ícono por defecto) NO pasa por aquí
      // — este mapa solo sabe agregar/actualizar el campo, nunca borrarlo.
      // Ver PerfilRepository.actualizarAvatarAsistente (usa
      // FieldValue.delete() cuando el usuario elige quitar su foto).
      if (avatarAsistenteBase64 != null) 'avatarAsistenteBase64': avatarAsistenteBase64,
      if (colorAnilloInicio != null) 'colorAnilloInicio': colorAnilloInicio,
      if (colorAnilloFin != null) 'colorAnilloFin': colorAnilloFin,
    };
  }

  PerfilUsuario copyWith({
    String? moneda,
    String? nombreAsistente,
    bool? onboardingCompletado,
    int? colorAnilloInicio,
    int? colorAnilloFin,
  }) {
    return PerfilUsuario(
      moneda: moneda ?? this.moneda,
      nombreAsistente: nombreAsistente ?? this.nombreAsistente,
      onboardingCompletado: onboardingCompletado ?? this.onboardingCompletado,
      avatarAsistenteBase64: avatarAsistenteBase64,
      colorAnilloInicio: colorAnilloInicio ?? this.colorAnilloInicio,
      colorAnilloFin: colorAnilloFin ?? this.colorAnilloFin,
    );
  }
}
