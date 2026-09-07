import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import 'data/auth_repository.dart';
import 'providers/auth_providers.dart';

/// Pantalla de "¿olvidaste tu contraseña?". Manda el correo de recuperación
/// de Firebase Auth y cambia a una vista de confirmación (_sent) — no hay
/// nada más que hacer aquí, el enlace del correo lo procesa Firebase.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(_emailCtrl.text.trim());
      setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthRepository.messageFor(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Olvidaste tu contraseña?', style: AppTextStyles.headlineLg),
              const SizedBox(height: 6),
              Text(
                'Te mandamos un enlace a tu correo para crear una nueva.',
                style: AppTextStyles.bodyMd,
              ),
              const SizedBox(height: 32),
              if (_sent) ...[
                // --- Vista de confirmación, después de enviar el correo ---
                Text(
                  '✓ Listo, revisa tu correo (${_emailCtrl.text.trim()}).',
                  style: AppTextStyles.bodyLg.copyWith(color: AppColors.inflowEmerald),
                ),
                const SizedBox(height: 20),
                // --- Botón "Volver al login" ---
                GradientButton(label: 'Volver al login', onPressed: () => context.pop()),
              ] else ...[
                // --- Campo de correo ---
                Text('CORREO ELECTRÓNICO', style: AppTextStyles.labelCode),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTextStyles.bodyLg,
                  decoration: const InputDecoration(hintText: 'tu@correo.com'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: AppTextStyles.bodyMd.copyWith(color: AppColors.outflowCrimson)),
                ],
                const SizedBox(height: 28),
                // --- Botón "Enviar enlace" (dispara el correo de recuperación) ---
                _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan))
                    : GradientButton(label: 'Enviar enlace', onPressed: _submit),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
