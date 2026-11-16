import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/anillo_asistente.dart';
import '../../core/router/app_shell.dart';
import '../../core/widgets/dialogo_formulario.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/piezas_escritorio.dart';
import '../onboarding/data/paleta_anillos_asistente.dart';
import '../onboarding/data/perfil_usuario.dart';
import '../onboarding/providers/perfil_providers.dart';
import 'widgets/configuracion_voz_asistente.dart';

// Nombres sugeridos para quien no se le ocurre uno — mismo estilo que el
// mockup de Stitch (Onboarding 2/3), pero aquí es solo un atajo: el campo
// de texto sigue aceptando cualquier nombre que el usuario escriba.
const _sugerenciasNombre = ['Lucy', 'Nero', 'Nova', 'Atlas', 'Aria'];

// Límite generoso sobre el archivo YA redimensionado por el selector de
// imágenes (ver maxWidth/maxHeight/imageQuality en _elegirFoto) — es solo
// un freno de seguridad para no guardar algo demasiado pesado en el
// documento de Firestore (que tiene un límite de 1 MiB por documento).
const _tamanoMaximoBytes = 500 * 1024;

/// Pantalla para personalizar "quién" es el asistente: su foto, su nombre
/// y el color del anillo que lo rodea en la pestaña inferior. A propósito
/// NO vive en el onboarding (que solo pide el nombre, ver
/// OnboardingFlowScreen) — se llega aquí cuando el usuario quiere, desde el
/// menú de Perfil. Inspirada en el mockup de Stitch
/// "6._onboarding_2_3_asistente_ia", pero sin la sección de "Tono de
/// asistencia" del mockup: esa personalidad configurable no existe de
/// verdad en el backend de IA todavía, y esta app no fabrica controles
/// que no hacen nada.
class PersonalizarAsistenteScreen extends ConsumerStatefulWidget {
  const PersonalizarAsistenteScreen({super.key});

  @override
  ConsumerState<PersonalizarAsistenteScreen> createState() =>
      _PersonalizarAsistenteScreenState();
}

class _PersonalizarAsistenteScreenState
    extends ConsumerState<PersonalizarAsistenteScreen> {
  late final TextEditingController _nombreCtrl;
  String? _avatarBase64;
  String? _avatarOriginal;
  late List<Color> _colorAnillo;
  bool _guardando = false;
  late String _vozNombre, _vozIdioma;
  late double _vozTono;
  late bool _revisarDictado;

  @override
  void initState() {
    super.initState();
    final perfil = ref.read(perfilProvider).value;
    _vozNombre = perfil?.vozNombre ?? '';
    _vozIdioma = perfil?.vozIdioma ?? 'es-MX';
    _vozTono = perfil?.vozTono ?? 1;
    _revisarDictado = perfil?.revisarDictado ?? false;
    _nombreCtrl = TextEditingController(
      text: perfil?.nombreAsistente ?? 'Lucy',
    );
    _avatarBase64 = perfil?.avatarAsistenteBase64;
    _avatarOriginal = _avatarBase64;

    final inicio = perfil?.colorAnilloInicio;
    final fin = perfil?.colorAnilloFin;
    _colorAnillo = (inicio != null && fin != null)
        ? [Color(inicio), Color(fin)]
        : List.of(AnilloAsistente.coloresPorDefecto);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  // --- Botón/foto "Toca para cambiar": abre la galería y guarda la
  // imagen elegida (ya redimensionada) como pendiente, hasta que se
  // presione "Guardar cambios" ---
  Future<void> _elegirFoto() async {
    final XFile? archivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 320,
      maxHeight: 320,
      imageQuality: 70,
    );
    if (archivo == null) return;

    final bytes = await archivo.readAsBytes();
    if (bytes.length > _tamanoMaximoBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Esa imagen sigue siendo muy pesada, intenta con otra.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _avatarBase64 = base64Encode(bytes));
  }

  // --- Botón "Quitar foto": vuelve al ícono de la app por defecto ---
  void _quitarFoto() => setState(() => _avatarBase64 = null);

  // --- Botón "Guardar cambios": persiste nombre, foto y color del anillo ---
  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      final nombre = _nombreCtrl.text.trim().isEmpty
          ? 'Lucy'
          : _nombreCtrl.text.trim();
      final repo = ref.read(perfilRepositoryProvider);
      final actual = ref.read(perfilProvider).value ?? PerfilUsuario.vacio;

      await repo.guardarPerfil(
        actual.copyWith(
          nombreAsistente: nombre,
          colorAnilloInicio: _colorAnillo[0].toARGB32(),
          colorAnilloFin: _colorAnillo[1].toARGB32(),
          vozNombre: _vozNombre,
          vozIdioma: _vozIdioma,
          vozTono: _vozTono,
          revisarDictado: _revisarDictado,
        ),
      );
      if (_avatarBase64 != _avatarOriginal) {
        await repo.actualizarAvatarAsistente(_avatarBase64);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = esEscritorio(context);
    final nombre = _nombreCtrl.text.trim().isEmpty
        ? 'Lucy'
        : _nombreCtrl.text.trim();

    // Entrada escalonada de las tarjetas.
    Widget entrada(Widget w, int orden) => w
        .animate()
        .fadeIn(delay: (80 * orden).ms, duration: 360.ms)
        .slideY(
          begin: 0.05,
          end: 0,
          delay: (80 * orden).ms,
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );

    final vistaPrevia = _VistaPrevia(
      nombre: nombre,
      avatarBase64: _avatarBase64,
      colores: _colorAnillo,
      onCambiarFoto: _elegirFoto,
      onQuitarFoto: _avatarBase64 == null ? null : _quitarFoto,
    );
    final accesoRapido = _AccesoRapido(
      nombre: nombre,
      avatarBase64: _avatarBase64,
      colores: _colorAnillo,
    );
    final apariencia = _Tarjeta(
      icono: Icons.auto_awesome_outlined,
      titulo: 'Apariencia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CampoEtiquetado(
            etiqueta: 'Nombre del asistente',
            child: TextField(
              controller: _nombreCtrl,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
              maxLength: 24,
              style: AppTextStyles.bodyLg.copyWith(fontSize: 18),
              decoration: decoracionCampo(pista: 'Lucy')
                  .copyWith(counterText: ''),
            ),
          ),
          const SizedBox(height: 14),
          // --- Sugerencias: un atajo, el campo acepta cualquier nombre ---
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (final sugerencia in _sugerenciasNombre)
                _ChipNombre(
                  texto: sugerencia,
                  elegido: nombre == sugerencia,
                  onTap: () => setState(() => _nombreCtrl.text = sugerencia),
                ),
            ],
          ),
          const SizedBox(height: 22),
          // --- Color del contorno: el degradado del anillo del asistente ---
          Text(
            'Color del contorno',
            style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              for (final par in paletaAnillosAsistente)
                _MuestraDegradado(
                  colores: par,
                  seleccionado:
                      par[0].toARGB32() == _colorAnillo[0].toARGB32() &&
                      par[1].toARGB32() == _colorAnillo[1].toARGB32(),
                  onTap: () => setState(() => _colorAnillo = par),
                ),
            ],
          ),
        ],
      ),
    );
    final voz = ConfiguracionVozAsistente(
      nombre: nombre,
      vozNombre: _vozNombre,
      vozIdioma: _vozIdioma,
      tono: _vozTono,
      revisar: _revisarDictado,
      onVoz: (n, idioma) => setState(() {
        _vozNombre = n;
        _vozIdioma = idioma;
      }),
      onTono: (tono) => setState(() => _vozTono = tono),
      onRevisar: (revisar) => setState(() => _revisarDictado = revisar),
    );
    final botones = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: _guardando ? null : () => Navigator.of(context).maybePop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(color: AppColors.glassStrokeHighlight),
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: AppTextStyles.bodyLg.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: FilledButton(
            onPressed: _guardando ? null : _guardar,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.acento,
              foregroundColor: AppColors.sobreAcento,
              disabledBackgroundColor: AppColors.acento.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: AppTextStyles.bodyLg.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            child: _guardando
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.sobreAcento,
                    ),
                  )
                : const Text('Guardar cambios'),
          ),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: ancho
              ? margenSeccionEscritorio
              : const EdgeInsets.fromLTRB(18, 10, 18, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: anchoMaximoSeccion),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  entrada(_Encabezado(nombre: nombre, ancho: ancho), 0),
                  SizedBox(height: ancho ? 26 : 18),
                  if (ancho)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 400,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              entrada(vistaPrevia, 1),
                              const SizedBox(height: 20),
                              entrada(accesoRapido, 2),
                            ],
                          ),
                        ),
                        const SizedBox(width: 26),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              entrada(apariencia, 2),
                              const SizedBox(height: 20),
                              entrada(voz, 3),
                              const SizedBox(height: 26),
                              botones,
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    entrada(vistaPrevia, 1),
                    const SizedBox(height: 16),
                    entrada(apariencia, 2),
                    const SizedBox(height: 16),
                    entrada(voz, 3),
                    const SizedBox(height: 16),
                    entrada(accesoRapido, 4),
                    const SizedBox(height: 22),
                    botones,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Lucy / Personalización", el título y el subtítulo.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.nombre, required this.ancho});

  final String nombre;
  final bool ancho;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!ancho)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ancho)
                Row(
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => context.go('/assistant'),
                        child: Text(
                          nombre,
                          style: AppTextStyles.bodyLg.copyWith(
                            color: AppColors.acento,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '   /   Personalización',
                      style: AppTextStyles.bodyLg.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              Text(
                'Personalizar asistente',
                style: AppTextStyles.display.copyWith(
                  fontSize: ancho ? 44 : 28,
                ),
              ),
              Text(
                'Dale tu estilo y elige cómo te habla.',
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: ancho ? 18 : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.child,
  });

  final IconData icono;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, color: AppColors.acento, size: 30),
              const SizedBox(width: 12),
              Text(titulo, style: AppTextStyles.headlineMd),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// Avatar con su anillo, nombre, cambiar foto y un saludo de muestra: así
/// se verá en el chat.
class _VistaPrevia extends StatelessWidget {
  const _VistaPrevia({
    required this.nombre,
    required this.avatarBase64,
    required this.colores,
    required this.onCambiarFoto,
    required this.onQuitarFoto,
  });

  final String nombre;
  final String? avatarBase64;
  final List<Color> colores;
  final VoidCallback onCambiarFoto;
  final VoidCallback? onQuitarFoto;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'VISTA PREVIA',
            style: AppTextStyles.labelCode.copyWith(letterSpacing: 2.5),
          ),
          const SizedBox(height: 18),
          Center(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onCambiarFoto,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (hijo, a) => ScaleTransition(
                    scale: Tween(begin: 0.92, end: 1.0).animate(a),
                    child: FadeTransition(opacity: a, child: hijo),
                  ),
                  child: AnilloAsistente(
                    key: ValueKey(
                      '${avatarBase64.hashCode}-${colores[0].toARGB32()}',
                    ),
                    avatarBase64: avatarBase64,
                    colores: colores,
                    size: 176,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            nombre,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.display.copyWith(fontSize: 30),
          ),
          Text(
            'Tu asistente de finanzas',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLg.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: onCambiarFoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Cambiar foto'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.acento, width: 1.4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 34,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: AppTextStyles.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (onQuitarFoto != null)
            Center(
              child: TextButton(
                onPressed: onQuitarFoto,
                child: Text(
                  'Usar imagen predeterminada',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          // --- Saludo de muestra, como se verá en el chat ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnilloAsistente(
                avatarBase64: avatarBase64,
                colores: colores,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2Glass,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.glassStrokeHighlight),
                  ),
                  child: Text(
                    'Hola, soy $nombre. ¿Qué registramos hoy?',
                    style: AppTextStyles.bodyLg,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cómo se verá el botón "Hablar con…" (solo muestra, no escucha).
class _AccesoRapido extends StatelessWidget {
  const _AccesoRapido({
    required this.nombre,
    required this.avatarBase64,
    required this.colores,
  });

  final String nombre;
  final String? avatarBase64;
  final List<Color> colores;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ACCESO RÁPIDO',
            style: AppTextStyles.labelCode.copyWith(letterSpacing: 2.5),
          ),
          const SizedBox(height: 16),
          ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    colores[0].withValues(alpha: 0.18),
                    colores[1].withValues(alpha: 0.18),
                  ],
                ),
                border: Border.all(color: colores[1].withValues(alpha: 0.8)),
              ),
              child: Row(
                children: [
                  AnilloAsistente(
                    avatarBase64: avatarBase64,
                    colores: colores,
                    size: 56,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Hablar con $nombre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineSm,
                    ),
                  ),
                  Icon(
                    Icons.mic_none_rounded,
                    color: AppColors.acento,
                    size: 30,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipNombre extends StatelessWidget {
  const _ChipNombre({
    required this.texto,
    required this.elegido,
    required this.onTap,
  });

  final String texto;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: elegido
          ? AppColors.acento.withValues(alpha: 0.10)
          : AppColors.surface2Glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: elegido ? AppColors.acento : AppColors.glassStrokeHighlight,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(texto, style: AppTextStyles.bodyLg),
              if (elegido) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_rounded, size: 20, color: AppColors.acento),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Una muestra circular de un degradado de 2 colores, tocable, con una
/// marca de verificación cuando es la elegida.
class _MuestraDegradado extends StatelessWidget {
  const _MuestraDegradado({
    required this.colores,
    required this.seleccionado,
    required this.onTap,
  });

  final List<Color> colores;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colores,
          ),
          border: seleccionado
              ? Border.all(color: AppColors.textPrimary, width: 2.5)
              : null,
          boxShadow: seleccionado
              ? [
                  BoxShadow(
                    color: colores[1].withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: seleccionado
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
