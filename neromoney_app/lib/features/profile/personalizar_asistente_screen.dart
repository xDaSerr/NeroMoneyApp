import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/anillo_asistente.dart';
import '../../core/widgets/gradient_button.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Personalizar asistente')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // --- Foto del asistente: toca para elegir una de la galería ---
              // (la vista previa ya incluye el anillo elegido abajo, para
              // que se vea tal cual se verá en la pestaña inferior)
              GestureDetector(
                onTap: _elegirFoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnilloAsistente(
                      avatarBase64: _avatarBase64,
                      colores: _colorAnillo,
                      size: 128,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryCyan,
                          border: Border.all(color: AppColors.canvas, width: 3),
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          size: 16,
                          color: AppColors.canvas,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Toca la foto para cambiarla', style: AppTextStyles.bodySm),
              if (_avatarBase64 != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _quitarFoto,
                  child: const Text('Quitar foto (usar la de la app)'),
                ),
              ],
              const SizedBox(height: 28),
              // --- Campo "Nombre del asistente" ---
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'NOMBRE DEL ASISTENTE',
                  style: AppTextStyles.labelCode,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nombreCtrl,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.words,
                style: AppTextStyles.headlineSm,
                decoration: const InputDecoration(hintText: 'Lucy'),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sugerencias rápidas:',
                  style: AppTextStyles.bodySm,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sugerencia in _sugerenciasNombre)
                      ActionChip(
                        label: Text(sugerencia),
                        backgroundColor: AppColors.surface3ActiveGlass,
                        labelStyle: AppTextStyles.bodySm,
                        side: BorderSide.none,
                        onPressed: () =>
                            setState(() => _nombreCtrl.text = sugerencia),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // --- Selector "Color del contorno": el degradado del
              // anillo que rodea la cara del asistente en la pestaña
              // inferior (ver AnilloAsistente / paleta_anillos_asistente) ---
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'COLOR DEL CONTORNO',
                  style: AppTextStyles.labelCode,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 14,
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
              ),
              const SizedBox(height: 32),
              ConfiguracionVozAsistente(
                nombre: _nombreCtrl.text,
                vozNombre: _vozNombre,
                vozIdioma: _vozIdioma,
                tono: _vozTono,
                revisar: _revisarDictado,
                onVoz: (nombre, idioma) => setState(() {
                  _vozNombre = nombre;
                  _vozIdioma = idioma;
                }),
                onTono: (tono) => setState(() => _vozTono = tono),
                onRevisar: (revisar) =>
                    setState(() => _revisarDictado = revisar),
              ),
              const SizedBox(height: 24),
              // --- Botón "Guardar cambios" ---
              _guardando
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: CircularProgressIndicator(
                        color: AppColors.primaryCyan,
                      ),
                    )
                  : GradientButton(
                      label: 'Guardar cambios',
                      onPressed: _guardar,
                    ),
              const SizedBox(height: 12),
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
        width: 40,
        height: 40,
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
