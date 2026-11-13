import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/gradient_button.dart';
import '../data/auth_repository.dart';
import '../providers/auth_providers.dart';
import 'piezas_acceso.dart';

// Los tres formularios viven dentro de la misma TarjetaAcceso
// (bienvenida_screen.dart), que es quien anima el cambio entre ellos. Ninguno
// navega al terminar: el redirect del router (app_router.dart) detecta la
// sesión nueva y manda a /onboarding o /home solo.

/// Entrada escalonada de los elementos de cada formulario: aparecen uno tras
/// otro, subiendo un poco, justo después de que la tarjeta termina de abrirse.
List<Widget> _escalonar(BuildContext context, List<Widget> hijos) {
  if (MediaQuery.disableAnimationsOf(context)) return hijos;
  return hijos
      .animate(delay: 120.ms, interval: 35.ms)
      .fadeIn(duration: 260.ms, curve: Curves.easeOut)
      .slideY(
        begin: 0.15,
        end: 0,
        duration: 320.ms,
        curve: Curves.easeOutCubic,
      );
}

/// Encabezado común: logo, título y subtítulo, centrados.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.titulo, required this.subtitulo});

  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LogoNeroMoney(),
        const SizedBox(height: 22),
        Text(
          titulo,
          style: AppTextStyles.headlineLg,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitulo,
          style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

/// Espacio fijo para el error dentro de la lista escalonada: si el mensaje
/// se insertara como un hijo nuevo, los elementos de abajo cambiarían de
/// posición y volverían a reproducir su animación de entrada. Aquí solo
/// crece de alto, suavemente.
class _ZonaError extends StatelessWidget {
  const _ZonaError(this.error);

  final String? error;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: error == null
          ? const SizedBox(width: double.infinity)
          : MensajeErrorAcceso(error!),
    );
  }
}

/// Botón principal que no cambia de alto al pasar a "cargando" — así la
/// tarjeta no da un brinco mientras se espera a Firebase.
class _BotonPrincipal extends StatelessWidget {
  const _BotonPrincipal({
    required this.cargando,
    required this.label,
    required this.onPressed,
    this.icono,
  });

  final bool cargando;
  final String label;
  final VoidCallback onPressed;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: cargando
            ? Center(
                child: SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(
                    color: AppColors.acento,
                    strokeWidth: 3,
                  ),
                ),
              )
            : GradientButton(label: label, icon: icono, onPressed: onPressed),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class FormularioLogin extends ConsumerStatefulWidget {
  const FormularioLogin({
    super.key,
    required this.onIrARegistro,
    required this.onOlvideContrasena,
  });

  final VoidCallback onIrARegistro;
  final VoidCallback onOlvideContrasena;

  @override
  ConsumerState<FormularioLogin> createState() => _FormularioLoginState();
}

class _FormularioLoginState extends ConsumerState<FormularioLogin> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _oculta = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrarConCorreo() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithEmail(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthRepository.messageFor(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _entrarConGoogle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthRepository.messageFor(e));
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar sesión con Google.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _escalonar(context, [
        const _Encabezado(
          titulo: 'Bienvenido de nuevo',
          subtitulo: 'Tu dinero, en orden.',
        ),

        // --- Campo de correo ---
        const EtiquetaCampo('Correo electrónico'),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          style: AppTextStyles.bodyLg,
          decoration: const InputDecoration(hintText: 'nombre@correo.com'),
        ),
        const SizedBox(height: 20),

        // --- Campo de contraseña (con ojo para mostrar/ocultar) ---
        const EtiquetaCampo('Contraseña'),
        TextField(
          controller: _passwordCtrl,
          obscureText: _oculta,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _cargando ? null : _entrarConCorreo(),
          style: AppTextStyles.bodyLg,
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              icon: Icon(
                _oculta
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _oculta = !_oculta),
            ),
          ),
        ),

        // --- Enlace "¿Olvidaste tu contraseña?" → formulario de recuperar ---
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: widget.onOlvideContrasena,
            child: Text(
              '¿Olvidaste tu contraseña?',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.acento,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        _ZonaError(_error),
        const SizedBox(height: 16),

        // --- Botón principal "Iniciar sesión" (correo y contraseña) ---
        _BotonPrincipal(
          cargando: _cargando,
          label: 'Iniciar sesión',
          icono: Icons.arrow_forward_rounded,
          onPressed: _entrarConCorreo,
        ),
        const SizedBox(height: 22),
        const SeparadorO(),
        const SizedBox(height: 22),

        // --- Botón "Continuar con Google" ---
        BotonVidrio(
          label: 'Continuar con Google',
          icono: const LogoGoogle(),
          onPressed: _cargando ? null : _entrarConGoogle,
        ),
        const SizedBox(height: 28),

        // --- Enlace "Crea tu cuenta" → formulario de registro ---
        EnlaceAcceso(
          texto: '¿Primera vez aquí?',
          enlace: 'Crea tu cuenta',
          onTap: widget.onIrARegistro,
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------

class FormularioRegistro extends ConsumerStatefulWidget {
  const FormularioRegistro({super.key, required this.onIrALogin});

  final VoidCallback onIrALogin;

  @override
  ConsumerState<FormularioRegistro> createState() => _FormularioRegistroState();
}

class _FormularioRegistroState extends ConsumerState<FormularioRegistro> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _oculta = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .registerWithEmail(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthRepository.messageFor(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _registrarConGoogle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      // Con Google, "registrarse" e "iniciar sesión" son lo mismo: Firebase
      // crea la cuenta la primera vez y el router manda al onboarding.
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthRepository.messageFor(e));
    } catch (_) {
      setState(() => _error = 'No se pudo continuar con Google.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _escalonar(context, [
        const _Encabezado(
          titulo: 'Crea tu cuenta',
          subtitulo: 'Empieza a ordenar tu dinero hoy.',
        ),

        // --- Campo de correo ---
        const EtiquetaCampo('Correo electrónico'),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          style: AppTextStyles.bodyLg,
          decoration: const InputDecoration(hintText: 'nombre@correo.com'),
        ),
        const SizedBox(height: 20),

        // --- Campo de contraseña ---
        const EtiquetaCampo('Contraseña'),
        TextField(
          controller: _passwordCtrl,
          obscureText: _oculta,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          style: AppTextStyles.bodyLg,
          decoration: InputDecoration(
            hintText: 'Mínimo 6 caracteres',
            suffixIcon: IconButton(
              icon: Icon(
                _oculta
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _oculta = !_oculta),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // --- Campo "Confirmar contraseña" ---
        const EtiquetaCampo('Confirmar contraseña'),
        TextField(
          controller: _confirmCtrl,
          obscureText: _oculta,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _cargando ? null : _registrar(),
          style: AppTextStyles.bodyLg,
          decoration: const InputDecoration(hintText: 'Repite tu contraseña'),
        ),
        _ZonaError(_error),
        const SizedBox(height: 28),

        // --- Botón principal "Crear cuenta" ---
        _BotonPrincipal(
          cargando: _cargando,
          label: 'Crear cuenta',
          icono: Icons.arrow_forward_rounded,
          onPressed: _registrar,
        ),
        const SizedBox(height: 22),
        const SeparadorO(),
        const SizedBox(height: 22),

        // --- Botón "Continuar con Google" ---
        BotonVidrio(
          label: 'Continuar con Google',
          icono: const LogoGoogle(),
          onPressed: _cargando ? null : _registrarConGoogle,
        ),
        const SizedBox(height: 28),

        // --- Enlace "Inicia sesión" → formulario de login ---
        EnlaceAcceso(
          texto: '¿Ya tienes cuenta?',
          enlace: 'Inicia sesión',
          onTap: widget.onIrALogin,
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------

class FormularioRecuperar extends ConsumerStatefulWidget {
  const FormularioRecuperar({super.key, required this.onVolver});

  final VoidCallback onVolver;

  @override
  ConsumerState<FormularioRecuperar> createState() =>
      _FormularioRecuperarState();
}

class _FormularioRecuperarState extends ConsumerState<FormularioRecuperar> {
  final _emailCtrl = TextEditingController();
  bool _cargando = false;
  bool _enviado = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(_emailCtrl.text.trim());
      setState(() => _enviado = true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthRepository.messageFor(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _escalonar(context, [
        const _Encabezado(
          titulo: '¿Olvidaste tu contraseña?',
          subtitulo: 'Te mandamos un enlace para crear una nueva.',
        ),
        if (_enviado) ...[
          // --- Confirmación, después de enviar el correo ---
          Text(
            '✓ Listo, revisa tu correo (${_emailCtrl.text.trim()}).',
            style: AppTextStyles.bodyLg.copyWith(
              color: AppColors.inflowEmerald,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
        ] else ...[
          // --- Campo de correo ---
          const EtiquetaCampo('Correo electrónico'),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _cargando ? null : _enviar(),
            style: AppTextStyles.bodyLg,
            decoration: const InputDecoration(hintText: 'nombre@correo.com'),
          ),
          _ZonaError(_error),
          const SizedBox(height: 28),

          // --- Botón "Enviar enlace" (correo de recuperación) ---
          _BotonPrincipal(
            cargando: _cargando,
            label: 'Enviar enlace',
            onPressed: _enviar,
          ),
          const SizedBox(height: 24),
        ],

        // --- Enlace "Volver a iniciar sesión" ---
        EnlaceAcceso(
          texto: '¿Ya la recordaste?',
          enlace: 'Volver a iniciar sesión',
          onTap: widget.onVolver,
        ),
      ]),
    );
  }
}
