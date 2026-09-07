import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import '../onboarding/data/perfil_usuario.dart';
import '../onboarding/providers/perfil_providers.dart';
import 'data/saludo_usuario.dart';

/// Pantalla para elegir el apodo (el nombre que se usa en los saludos, ej.
/// "Hola, Apodo" en Inicio) y, si el usuario quiere, su nombre real —
/// 100% opcional y solo informativo, nunca reemplaza al apodo en los
/// saludos. Se llega aquí desde el menú de Perfil ("Editar perfil").
class EditarPerfilScreen extends ConsumerStatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  ConsumerState<EditarPerfilScreen> createState() =>
      _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends ConsumerState<EditarPerfilScreen> {
  late final TextEditingController _apodoCtrl;
  late final TextEditingController _nombreCompletoCtrl;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final perfil = ref.read(perfilProvider).value;
    // Si el usuario nunca eligió un apodo, se prellena con lo que ya se
    // usaba antes (nombre de Google o prefijo del correo) en vez de dejar
    // el campo vacío — así solo tiene que confirmarlo o ajustarlo, no
    // escribir uno desde cero.
    final apodoActual = perfil?.apodo ?? '';
    final apodoSugerido = apodoActual.isNotEmpty
        ? apodoActual
        : datosDeSaludo(FirebaseAuth.instance.currentUser, null).nombre;
    _apodoCtrl = TextEditingController(text: apodoSugerido);
    _nombreCompletoCtrl = TextEditingController(
      text: perfil?.nombreCompleto ?? '',
    );
  }

  @override
  void dispose() {
    _apodoCtrl.dispose();
    _nombreCompletoCtrl.dispose();
    super.dispose();
  }

  // --- Botón "Guardar cambios": persiste apodo y nombre real ---
  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      final repo = ref.read(perfilRepositoryProvider);
      final actual = ref.read(perfilProvider).value ?? PerfilUsuario.vacio;
      await repo.guardarPerfil(
        actual.copyWith(
          apodo: _apodoCtrl.text.trim(),
          nombreCompleto: _nombreCompletoCtrl.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apodoVista = _apodoCtrl.text.trim().isEmpty
        ? 'Apodo'
        : _apodoCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Campo "Apodo": lo que se muestra en "Hola, X" en Inicio ---
              Text('APODO', style: AppTextStyles.labelCode),
              const SizedBox(height: 8),
              TextField(
                controller: _apodoCtrl,
                onChanged: (_) => setState(() {}), // refresca la vista previa de abajo
                textCapitalization: TextCapitalization.words,
                style: AppTextStyles.headlineSm,
                decoration: const InputDecoration(hintText: 'ej. Dani'),
              ),
              const SizedBox(height: 6),
              Text(
                'Así te saluda la app en Inicio ("Hola, $apodoVista"). Si lo dejas '
                'vacío, usamos el nombre de tu cuenta de Google o tu correo.',
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: 28),
              // --- Campo "Nombre real": opcional, solo informativo ---
              Text('NOMBRE REAL (OPCIONAL)', style: AppTextStyles.labelCode),
              const SizedBox(height: 8),
              TextField(
                controller: _nombreCompletoCtrl,
                textCapitalization: TextCapitalization.words,
                style: AppTextStyles.bodyLg,
                decoration: const InputDecoration(
                  hintText: 'ej. Daniel Serrano',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Nunca se usa en los saludos ni se comparte con nadie — solo se '
                'muestra aquí, en tu Perfil.',
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: 32),
              // --- Botón "Guardar cambios" ---
              _guardando
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryCyan,
                        ),
                      ),
                    )
                  : GradientButton(label: 'Guardar cambios', onPressed: _guardar),
            ],
          ),
        ),
      ),
    );
  }
}
