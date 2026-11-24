import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/fecha_es.dart';
import '../../core/widgets/gradient_button.dart';
import '../onboarding/data/perfil_usuario.dart';
import '../onboarding/providers/perfil_providers.dart';
import 'data/saludo_usuario.dart';
import 'widgets/foto_usuario.dart';

// Freno de seguridad: Firestore admite 1 MiB por documento y la foto vive
// en el perfil (igual que la de la asistente).
const _tamanoMaximoBytes = 400 * 1024;
const _largoFrase = 60;

/// Todo lo que personaliza al usuario: foto, apodo (el de los saludos),
/// nombre real opcional, una frase corta y su cumpleaños (ese día Inicio lo
/// felicita). Se llega desde Perfil → "Editar perfil". Nada se guarda hasta
/// tocar "Guardar cambios".
User? _usuarioActual() {
  try {
    return FirebaseAuth.instance.currentUser;
  } catch (_) {
    return null; // sin Firebase inicializado (pruebas)
  }
}

class EditarPerfilScreen extends ConsumerStatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  ConsumerState<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends ConsumerState<EditarPerfilScreen> {
  String? _foto; // base64 pendiente de guardar
  bool _fotoCambio = false;
  ({int mes, int dia})? _cumpleanos;
  bool _guardando = false;

  final _apodoCtrl = TextEditingController();
  final _nombreCompletoCtrl = TextEditingController();
  final _fraseCtrl = TextEditingController();
  bool _rellenado = false;

  @override
  void initState() {
    super.initState();
    // Si se abre antes de que llegue el perfil (ej. recargando en esta
    // ruta), se rellena cuando llegue: nunca se guarda un formulario vacío
    // encima de los datos reales.
    final perfil = ref.read(perfilProvider).value;
    if (perfil != null) {
      _rellenar(perfil);
    } else {
      ref.listenManual(perfilProvider, (_, siguiente) {
        final p = siguiente.value;
        if (p != null && !_rellenado && mounted) setState(() => _rellenar(p));
      });
    }
  }

  void _rellenar(PerfilUsuario perfil) {
    _rellenado = true;
    // Si nunca eligió apodo, se prellena con el nombre de Google o el
    // prefijo del correo: solo tiene que confirmarlo.
    _apodoCtrl.text = perfil.apodo.isNotEmpty
        ? perfil.apodo
        : datosDeSaludo(_usuarioActual(), null).nombre;
    _nombreCompletoCtrl.text = perfil.nombreCompleto;
    _fraseCtrl.text = perfil.frase;
    _foto = perfil.fotoUsuarioBase64;
    _cumpleanos = perfil.cumpleanos;
  }

  @override
  void dispose() {
    _apodoCtrl.dispose();
    _nombreCompletoCtrl.dispose();
    _fraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto() async {
    final archivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 75,
    );
    if (archivo == null) return;
    final bytes = await archivo.readAsBytes();
    if (bytes.length > _tamanoMaximoBytes) {
      _avisar('Esa imagen es muy pesada, intenta con otra.');
      return;
    }
    setState(() {
      _foto = base64Encode(bytes);
      _fotoCambio = true;
    });
  }

  void _quitarFoto() => setState(() {
    _foto = null;
    _fotoCambio = true;
  });

  Future<void> _elegirCumpleanos() async {
    final hoy = DateTime.now();
    // El año no se guarda: el calendario usa uno bisiesto para que el
    // 29 de febrero también se pueda elegir.
    final actual = _cumpleanos;
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual == null
          ? DateTime(2024, hoy.month, hoy.day)
          : DateTime(2024, actual.mes, actual.dia),
      firstDate: DateTime(2024),
      lastDate: DateTime(2024, 12, 31),
      initialDatePickerMode: DatePickerMode.day,
      helpText: 'TU CUMPLEAÑOS',
    );
    if (elegida != null) {
      setState(() => _cumpleanos = (mes: elegida.month, dia: elegida.day));
    }
  }

  Future<void> _guardar() async {
    if (_guardando || !_rellenado) return;
    setState(() => _guardando = true);
    try {
      final repo = ref.read(perfilRepositoryProvider);
      final actual = ref.read(perfilProvider).value ?? PerfilUsuario.vacio;
      await repo.guardarPerfil(
        actual.copyWith(
          apodo: _apodoCtrl.text.trim(),
          nombreCompleto: _nombreCompletoCtrl.text.trim(),
          frase: _fraseCtrl.text.trim(),
          cumpleanos: _cumpleanos,
        ),
      );
      // La foto va aparte: quitarla necesita borrar el campo de verdad.
      if (_fotoCambio) await repo.actualizarFotoUsuario(_foto);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _avisar('No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final apodoVista = _apodoCtrl.text.trim().isEmpty
        ? 'Apodo'
        : _apodoCtrl.text.trim();
    final inicial = apodoVista.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // --- Foto de perfil ---
                Center(
                  child: GestureDetector(
                    onTap: _elegirFoto,
                    child: Stack(
                      children: [
                        FotoUsuario(base64: _foto, inicial: inicial, radio: 56),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.acento,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface1,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.photo_camera_rounded,
                              size: 18,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _elegirFoto,
                      child: Text(_foto == null ? 'Subir foto' : 'Cambiar foto'),
                    ),
                    if (_foto != null)
                      TextButton(
                        onPressed: _quitarFoto,
                        child: Text(
                          'Quitar',
                          style: TextStyle(color: AppColors.outflowCrimson),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // --- Apodo ---
                Text('APODO', style: AppTextStyles.labelCode),
                const SizedBox(height: 8),
                TextField(
                  controller: _apodoCtrl,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.words,
                  style: AppTextStyles.headlineSm,
                ),
                const SizedBox(height: 6),
                Text(
                  'Así te saluda la app ("Hola, $apodoVista"). Si lo dejas vacío, '
                  'usamos el nombre de tu cuenta de Google o tu correo.',
                  style: AppTextStyles.bodySm,
                ),
                const SizedBox(height: 26),

                // --- Nombre real ---
                Text('NOMBRE REAL (OPCIONAL)', style: AppTextStyles.labelCode),
                const SizedBox(height: 8),
                TextField(
                  controller: _nombreCompletoCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: AppTextStyles.bodyLg,
                ),
                const SizedBox(height: 6),
                Text(
                  'Solo se muestra en tu Perfil; nunca en los saludos.',
                  style: AppTextStyles.bodySm,
                ),
                const SizedBox(height: 26),

                // --- Frase ---
                Text('TU FRASE (OPCIONAL)', style: AppTextStyles.labelCode),
                const SizedBox(height: 8),
                TextField(
                  controller: _fraseCtrl,
                  maxLength: _largoFrase,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.bodyLg,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Ahorrando para mi primer carro 🚗',
                  ),
                ),
                const SizedBox(height: 14),

                // --- Cumpleaños ---
                Text('CUMPLEAÑOS (OPCIONAL)', style: AppTextStyles.labelCode),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _elegirCumpleanos,
                        icon: const Icon(Icons.cake_rounded),
                        label: Text(
                          _cumpleanos == null
                              ? 'Elegir día'
                              : '${_cumpleanos!.dia} de ${mesesEs[_cumpleanos!.mes - 1]}',
                        ),
                      ),
                    ),
                    if (_cumpleanos != null)
                      IconButton(
                        tooltip: 'Quitar',
                        onPressed: () => setState(() => _cumpleanos = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Solo el día y el mes. Ese día te felicitamos en Inicio.',
                  style: AppTextStyles.bodySm,
                ),
                const SizedBox(height: 32),

                _guardando
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.acento,
                          ),
                        ),
                      )
                    : GradientButton(
                        label: 'Guardar cambios',
                        onPressed: _guardar,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
