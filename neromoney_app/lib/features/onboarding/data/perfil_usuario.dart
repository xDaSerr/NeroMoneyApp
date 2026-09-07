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
    this.vozNombre = '',
    this.vozIdioma = 'es-MX',
    this.vozTono = 1.0,
    this.revisarDictado = false,
    this.apodo = '',
    this.nombreCompleto = '',
    this.recordatoriosActivados = false,
    this.horaRecordatorio1 = 14 * 60,
    this.horaRecordatorio2 = 20 * 60,
  });

  final String moneda; // código ISO: "MXN", "USD", etc.
  final String nombreAsistente;
  final bool onboardingCompletado;
  final String vozNombre;
  final String vozIdioma;
  final double vozTono;
  final bool revisarDictado;

  // Apodo elegido a mano en Perfil → Editar perfil (ver EditarPerfilScreen):
  // es lo que se muestra en saludos ("Hola, Apodo" en Inicio) y en el
  // encabezado de Perfil. Vacío = todavía no lo puso — en ese caso
  // `datosDeSaludo` (features/profile/data/saludo_usuario.dart) cae al
  // nombre real de Google Sign-In, y si tampoco hay eso, al prefijo del
  // correo, para que el saludo nunca quede vacío.
  final String apodo;

  // Nombre real, 100% opcional y solo informativo (se muestra en el
  // encabezado de Perfil) — a propósito nunca sustituye al apodo en los
  // saludos, para no obligar a nadie a compartir su nombre legal.
  final String nombreCompleto;

  // Recordatorios locales para no olvidar registrar gastos (ver
  // features/reminders/data/recordatorios_service.dart) — apagados por
  // defecto (decisión explícita: nada se activa solo, ni notificaciones, sin
  // que el usuario lo pida — mismo criterio que el resto de la app). Las
  // horas se guardan en minutos desde medianoche (14*60 = 2:00 p.m., 20*60 =
  // 8:00 p.m. por defecto) en vez de String "HH:mm" para no tener que
  // parsear/formatear en cada lectura.
  final bool recordatoriosActivados;
  final int horaRecordatorio1; // recordatorio de mediodía
  final int horaRecordatorio2; // recordatorio de la noche

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

  factory PerfilUsuario.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists) return vacio;
    final data = doc.data()!;
    return PerfilUsuario(
      moneda: data['moneda'] as String? ?? vacio.moneda,
      nombreAsistente:
          data['nombreAsistente'] as String? ?? vacio.nombreAsistente,
      onboardingCompletado: data['onboardingCompletado'] as bool? ?? false,
      avatarAsistenteBase64: data['avatarAsistenteBase64'] as String?,
      colorAnilloInicio: data['colorAnilloInicio'] as int?,
      colorAnilloFin: data['colorAnilloFin'] as int?,
      vozNombre: data['vozNombre'] as String? ?? '',
      vozIdioma: data['vozIdioma'] as String? ?? 'es-MX',
      vozTono: ((data['vozTono'] as num?)?.toDouble() ?? 1).clamp(0.7, 1.3),
      revisarDictado: data['revisarDictado'] as bool? ?? false,
      apodo: data['apodo'] as String? ?? '',
      nombreCompleto: data['nombreCompleto'] as String? ?? '',
      recordatoriosActivados: data['recordatoriosActivados'] as bool? ?? false,
      horaRecordatorio1: data['horaRecordatorio1'] as int? ?? 14 * 60,
      horaRecordatorio2: data['horaRecordatorio2'] as int? ?? 20 * 60,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'moneda': moneda,
      'nombreAsistente': nombreAsistente,
      'onboardingCompletado': onboardingCompletado,
      'vozNombre': vozNombre,
      'vozIdioma': vozIdioma,
      'vozTono': vozTono,
      'revisarDictado': revisarDictado,
      'apodo': apodo,
      'nombreCompleto': nombreCompleto,
      'recordatoriosActivados': recordatoriosActivados,
      'horaRecordatorio1': horaRecordatorio1,
      'horaRecordatorio2': horaRecordatorio2,
      // OJO: quitar la foto (volver al ícono por defecto) NO pasa por aquí
      // — este mapa solo sabe agregar/actualizar el campo, nunca borrarlo.
      // Ver PerfilRepository.actualizarAvatarAsistente (usa
      // FieldValue.delete() cuando el usuario elige quitar su foto).
      if (avatarAsistenteBase64 != null)
        'avatarAsistenteBase64': avatarAsistenteBase64,
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
    String? vozNombre,
    String? vozIdioma,
    double? vozTono,
    bool? revisarDictado,
    String? apodo,
    String? nombreCompleto,
    bool? recordatoriosActivados,
    int? horaRecordatorio1,
    int? horaRecordatorio2,
  }) {
    return PerfilUsuario(
      moneda: moneda ?? this.moneda,
      nombreAsistente: nombreAsistente ?? this.nombreAsistente,
      onboardingCompletado: onboardingCompletado ?? this.onboardingCompletado,
      avatarAsistenteBase64: avatarAsistenteBase64,
      colorAnilloInicio: colorAnilloInicio ?? this.colorAnilloInicio,
      colorAnilloFin: colorAnilloFin ?? this.colorAnilloFin,
      vozNombre: vozNombre ?? this.vozNombre,
      vozIdioma: vozIdioma ?? this.vozIdioma,
      vozTono: vozTono ?? this.vozTono,
      revisarDictado: revisarDictado ?? this.revisarDictado,
      apodo: apodo ?? this.apodo,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      recordatoriosActivados:
          recordatoriosActivados ?? this.recordatoriosActivados,
      horaRecordatorio1: horaRecordatorio1 ?? this.horaRecordatorio1,
      horaRecordatorio2: horaRecordatorio2 ?? this.horaRecordatorio2,
    );
  }
}
