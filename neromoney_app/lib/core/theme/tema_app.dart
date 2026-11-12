import 'package:flutter/material.dart';

/// Los 8 colores de app que el usuario elige en el onboarding (y después en
/// Perfil). Cada uno pinta el fondo completo — no solo un acento — y
/// "Blanco" es un modo claro de verdad (decisión explícita del usuario).
/// El nombre del enum es lo que se guarda en Firestore (`usuarios/{uid}.tema`).
enum TemaApp { negro, blanco, rojo, naranja, verde, azul, morado, rosa }

extension TemaAppNombre on TemaApp {
  String get etiqueta => switch (this) {
    TemaApp.negro => 'Negro',
    TemaApp.blanco => 'Blanco',
    TemaApp.rojo => 'Rojo',
    TemaApp.naranja => 'Naranja',
    TemaApp.verde => 'Verde',
    TemaApp.azul => 'Azul',
    TemaApp.morado => 'Morado',
    TemaApp.rosa => 'Rosa',
  };

  static TemaApp desdeTexto(String? texto) => TemaApp.values.firstWhere(
    (t) => t.name == texto,
    orElse: () => TemaApp.negro,
  );
}

/// Todos los colores de una paleta. Los nombres son por función (acento,
/// secundario…), no por tono: el "acento" del tema Rojo es rojo, el del Negro
/// es el cian original del diseño "Obsidian Cyber-Glass".
@immutable
class PaletaTema {
  const PaletaTema({
    required this.tema,
    required this.brillo,
    required this.canvas,
    required this.surface1,
    required this.surface2Glass,
    required this.surface3ActiveGlass,
    required this.acento,
    required this.acentoPresionado,
    required this.sobreAcento,
    required this.secundario,
    required this.secundarioClaro,
    required this.secundarioProfundo,
    required this.textPrimary,
    required this.textSecondary,
    required this.textPlaceholder,
    required this.glassStrokeStandard,
    required this.glassStrokeHighlight,
    required this.degradadoAccion,
    required this.degradadoBurbuja,
    required this.resplandores,
  });

  final TemaApp tema;
  final Brightness brillo;

  // Fondo y superficies
  final Color canvas;
  final Color surface1; // tarjetas, hojas base
  final Color surface2Glass; // vidrio translúcido
  final Color surface3ActiveGlass; // relleno sutil de campos/insignias

  // Acentos
  final Color acento;
  final Color acentoPresionado;
  final Color sobreAcento; // texto/ícono encima de un botón con el acento
  final Color secundario;
  final Color secundarioClaro;
  final Color secundarioProfundo;

  // Texto
  final Color textPrimary;
  final Color textSecondary;
  final Color textPlaceholder;

  // Bordes de vidrio
  final Color glassStrokeStandard;
  final Color glassStrokeHighlight;

  /// Degradado del botón principal: la "combinación" de cada color.
  final List<Color> degradadoAccion;

  /// Burbuja de los mensajes del usuario en el chat.
  final List<Color> degradadoBurbuja;

  /// Los dos brillos difusos de las esquinas del fondo (ver FondoTema).
  final List<Color> resplandores;

  bool get esClaro => brillo == Brightness.light;
  Color get brilloAcento => acento.withValues(alpha: 0.25);

  static PaletaTema de(TemaApp tema) => _paletas[tema]!;

  // Las 7 oscuras comparten textos y bordes: el fondo cambia de tinte, la
  // legibilidad no.
  static const _textoOscuro = Color(0xFFFFFFFF);
  static const _textoOscuro2 = Color(0xFF94A3B8);
  static const _textoOscuro3 = Color(0xFF64748B);
  static const _bordeOscuro = Color(0x14FFFFFF);
  static const _bordeOscuro2 = Color(0x29FFFFFF);
  static const _rellenoOscuro = Color(0x0AFFFFFF);

  static PaletaTema _oscura({
    required TemaApp tema,
    required Color canvas,
    required Color surface1,
    required Color acento,
    required Color acentoPresionado,
    required Color finAccion,
    required Color secundario,
    required Color secundarioClaro,
    required Color secundarioProfundo,
    required List<Color> burbuja,
    required List<Color> resplandores,
  }) => PaletaTema(
    tema: tema,
    brillo: Brightness.dark,
    canvas: canvas,
    surface1: surface1,
    surface2Glass: surface1.withValues(alpha: 0.70),
    surface3ActiveGlass: _rellenoOscuro,
    acento: acento,
    acentoPresionado: acentoPresionado,
    sobreAcento: canvas,
    secundario: secundario,
    secundarioClaro: secundarioClaro,
    secundarioProfundo: secundarioProfundo,
    textPrimary: _textoOscuro,
    textSecondary: _textoOscuro2,
    textPlaceholder: _textoOscuro3,
    glassStrokeStandard: _bordeOscuro,
    glassStrokeHighlight: _bordeOscuro2,
    degradadoAccion: [acento, finAccion],
    degradadoBurbuja: burbuja,
    resplandores: resplandores,
  );

  static final Map<TemaApp, PaletaTema> _paletas = {
    // El diseño original "Obsidian Cyber-Glass" (Stitch), sin cambios.
    TemaApp.negro: _oscura(
      tema: TemaApp.negro,
      canvas: const Color(0xFF0A0D14),
      surface1: const Color(0xFF121826),
      acento: const Color(0xFF00F0FF),
      acentoPresionado: const Color(0xFF00D2FF),
      finAccion: const Color(0xFF00B4D8),
      secundario: const Color(0xFF8A2BE2),
      secundarioClaro: const Color(0xFFA855F7),
      secundarioProfundo: const Color(0xFF7B2CBF),
      burbuja: const [Color(0xFF7B2CBF), Color(0xFF5A189A)],
      resplandores: const [Color(0xFF00F0FF), Color(0xFF8A2BE2)],
    ),
    TemaApp.rojo: _oscura(
      tema: TemaApp.rojo,
      canvas: const Color(0xFF140A0D),
      surface1: const Color(0xFF231218),
      acento: const Color(0xFFFF4D6A),
      acentoPresionado: const Color(0xFFE63E5A),
      finAccion: const Color(0xFFFF8A4C),
      secundario: const Color(0xFFFF8A4C),
      secundarioClaro: const Color(0xFFFFB37A),
      secundarioProfundo: const Color(0xFFC2410C),
      burbuja: const [Color(0xFFB91C3C), Color(0xFF7F1D1D)],
      resplandores: const [Color(0xFFFF4D6A), Color(0xFFFF8A4C)],
    ),
    TemaApp.naranja: _oscura(
      tema: TemaApp.naranja,
      canvas: const Color(0xFF140E08),
      surface1: const Color(0xFF231910),
      acento: const Color(0xFFFFA726),
      acentoPresionado: const Color(0xFFF59300),
      finAccion: const Color(0xFFFF6A3D),
      secundario: const Color(0xFFFF6A3D),
      secundarioClaro: const Color(0xFFFF9A76),
      secundarioProfundo: const Color(0xFFC2410C),
      burbuja: const [Color(0xFFC2410C), Color(0xFF9A3412)],
      resplandores: const [Color(0xFFFFA726), Color(0xFFFF5E3A)],
    ),
    TemaApp.verde: _oscura(
      tema: TemaApp.verde,
      canvas: const Color(0xFF07120F),
      surface1: const Color(0xFF0F1F1A),
      acento: const Color(0xFF2EE6A6),
      acentoPresionado: const Color(0xFF1FCB90),
      finAccion: const Color(0xFF14B8A6),
      secundario: const Color(0xFF06B6D4),
      secundarioClaro: const Color(0xFF67E8F9),
      secundarioProfundo: const Color(0xFF0E7490),
      burbuja: const [Color(0xFF0F766E), Color(0xFF115E59)],
      resplandores: const [Color(0xFF2EE6A6), Color(0xFF06B6D4)],
    ),
    TemaApp.azul: _oscura(
      tema: TemaApp.azul,
      canvas: const Color(0xFF080D1A),
      surface1: const Color(0xFF101A2E),
      acento: const Color(0xFF4D9BFF),
      acentoPresionado: const Color(0xFF2F80ED),
      finAccion: const Color(0xFF00C2FF),
      secundario: const Color(0xFF6366F1),
      secundarioClaro: const Color(0xFF818CF8),
      secundarioProfundo: const Color(0xFF4338CA),
      burbuja: const [Color(0xFF4338CA), Color(0xFF312E81)],
      resplandores: const [Color(0xFF4D9BFF), Color(0xFF6366F1)],
    ),
    TemaApp.morado: _oscura(
      tema: TemaApp.morado,
      canvas: const Color(0xFF0E0A18),
      surface1: const Color(0xFF1A1430),
      acento: const Color(0xFFB57BFF),
      acentoPresionado: const Color(0xFFA065F5),
      finAccion: const Color(0xFFFF5CC8),
      secundario: const Color(0xFFFF5CC8),
      secundarioClaro: const Color(0xFFFF8AD8),
      secundarioProfundo: const Color(0xFFBE185D),
      burbuja: const [Color(0xFF7B2CBF), Color(0xFF5A189A)],
      resplandores: const [Color(0xFF9D4EDD), Color(0xFFFF5CC8)],
    ),
    TemaApp.rosa: _oscura(
      tema: TemaApp.rosa,
      canvas: const Color(0xFF160A12),
      surface1: const Color(0xFF25121F),
      acento: const Color(0xFFFF5CA8),
      acentoPresionado: const Color(0xFFF0438F),
      finAccion: const Color(0xFFC084FC),
      secundario: const Color(0xFFC084FC),
      secundarioClaro: const Color(0xFFD8B4FE),
      secundarioProfundo: const Color(0xFF9333EA),
      burbuja: const [Color(0xFFBE185D), Color(0xFF831843)],
      resplandores: const [Color(0xFFFF5CA8), Color(0xFFC084FC)],
    ),
    // Modo claro: fondo gris muy claro, tarjetas blancas, texto casi negro.
    // El acento es índigo porque el cian sobre blanco casi no se lee.
    TemaApp.blanco: const PaletaTema(
      tema: TemaApp.blanco,
      brillo: Brightness.light,
      canvas: Color(0xFFF4F5FA),
      surface1: Color(0xFFFFFFFF),
      surface2Glass: Color(0xD9FFFFFF),
      surface3ActiveGlass: Color(0x0A0F172A),
      acento: Color(0xFF4F46E5),
      acentoPresionado: Color(0xFF4338CA),
      sobreAcento: Color(0xFFFFFFFF),
      secundario: Color(0xFF7C3AED),
      secundarioClaro: Color(0xFF8B5CF6),
      secundarioProfundo: Color(0xFF6D28D9),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF475569),
      textPlaceholder: Color(0xFF94A3B8),
      glassStrokeStandard: Color(0x1A0F172A),
      glassStrokeHighlight: Color(0x2E0F172A),
      degradadoAccion: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
      degradadoBurbuja: [Color(0xFF4F46E5), Color(0xFF6D28D9)],
      resplandores: [Color(0xFF818CF8), Color(0xFFC4B5FD)],
    ),
  };
}
