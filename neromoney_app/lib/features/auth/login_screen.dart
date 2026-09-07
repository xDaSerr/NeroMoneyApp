import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import 'data/auth_repository.dart';
import 'providers/auth_providers.dart';

/// Pantalla de inicio de sesión, ya conectada a Firebase Auth (email/
/// contraseña y Google). El redirect del router (ver app_router.dart) es
/// quien te manda a /home apenas detecta que hay sesión — esta pantalla
/// solo dispara el login y muestra errores, nunca navega "a mano".
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthRepository.messageFor(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthRepository.messageFor(e));
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar sesión con Google.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bienvenido de nuevo', style: AppTextStyles.headlineLg),
              const SizedBox(height: 6),
              Text(
                'Ingresa a tu portal financiero inteligente',
                style: AppTextStyles.bodyMd,
              ),
              const SizedBox(height: 32),

              // --- Campo de correo ---
              Text('CORREO ELECTRÓNICO', style: AppTextStyles.labelCode),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.bodyLg,
                decoration: const InputDecoration(
                  hintText: 'tu@correo.com',
                  prefixIcon: Icon(Icons.mail_outline, color: AppColors.textPlaceholder),
                ),
              ),
              const SizedBox(height: 20),

              // --- Campo de contraseña (con botón de ojo para mostrar/ocultar) ---
              Text('CONTRASEÑA', style: AppTextStyles.labelCode),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                style: AppTextStyles.bodyLg,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textPlaceholder),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textPlaceholder,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              // --- Botón/enlace "¿Olvidaste tu contraseña?" → /forgot-password ---
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: AppTextStyles.bodyMd.copyWith(color: AppColors.outflowCrimson)),
              ],
              const SizedBox(height: 16),

              // --- Botón principal "Iniciar sesión" (login con email/contraseña) ---
              _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan))
                  : GradientButton(
                      label: 'Iniciar sesión',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _signInWithEmail,
                    ),
              const SizedBox(height: 24),

              // --- Separador "O CONTINÚA CON" ---
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('O CONTINÚA CON', style: AppTextStyles.labelCode),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              // --- Botón "Continuar con Google" (Google Sign-In) ---
              OutlinedButton.icon(
                onPressed: _loading ? null : _signInWithGoogle,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                label: const Text('Continuar con Google'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  side: const BorderSide(color: AppColors.glassStrokeStandard),
                  shape: const StadiumBorder(),
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),

              // --- Enlace "Crear cuenta" (al final, va a /register) ---
              Center(
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodyMd,
                    children: [
                      const TextSpan(text: '¿No tienes cuenta? '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () => context.push('/register'),
                          child: Text(
                            'Crear cuenta',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.primaryCyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
