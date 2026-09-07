import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import 'data/auth_repository.dart';
import 'providers/auth_providers.dart';

/// Pantalla de registro con email/contraseña. Al terminar no navega a mano:
/// el redirect del router (ver app_router.dart) detecta la nueva sesión y
/// te manda a /onboarding o /home según corresponda.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).registerWithEmail(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      // El redirect del router se encarga de mandarte a /home al detectar
      // la nueva sesión — no hace falta navegar manualmente aquí.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthRepository.messageFor(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Únete a NeroMoney', style: AppTextStyles.headlineLg),
              const SizedBox(height: 6),
              Text('Crea tu cuenta para empezar a organizar tus finanzas',
                  style: AppTextStyles.bodyMd),
              const SizedBox(height: 32),

              // --- Campo de correo ---
              Text('CORREO ELECTRÓNICO', style: AppTextStyles.labelCode),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.bodyLg,
                decoration: const InputDecoration(hintText: 'tu@correo.com'),
              ),
              const SizedBox(height: 20),

              // --- Campo de contraseña ---
              Text('CONTRASEÑA', style: AppTextStyles.labelCode),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                style: AppTextStyles.bodyLg,
                decoration: InputDecoration(
                  hintText: 'Mínimo 6 caracteres',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textPlaceholder,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Campo de confirmación de contraseña ---
              Text('CONFIRMAR CONTRASEÑA', style: AppTextStyles.labelCode),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscure,
                style: AppTextStyles.bodyLg,
                decoration: const InputDecoration(hintText: 'Repite tu contraseña'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: AppTextStyles.bodyMd.copyWith(color: AppColors.outflowCrimson)),
              ],
              const SizedBox(height: 28),

              // --- Botón principal "Crear cuenta" (envía el registro) ---
              _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan))
                  : GradientButton(label: 'Crear cuenta', onPressed: _register),
              const SizedBox(height: 20),

              // --- Enlace para volver al login ---
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
