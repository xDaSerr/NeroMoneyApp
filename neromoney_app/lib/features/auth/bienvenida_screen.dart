import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import 'widgets/fondo_acceso.dart';
import 'widgets/formularios_acceso.dart';
import 'widgets/piezas_acceso.dart';

enum ModoAcceso { portada, login, registro, recuperar }

/// Puerta de entrada de la app (rutas /login, /register y /forgot-password):
/// el fondo animado se queda fijo y lo que cambia encima es la portada
/// ("Iniciar sesión" / "Registrarme") o la tarjeta de vidrio con cada
/// formulario. Todo vive en una sola pantalla a propósito — si cada
/// formulario fuera una ruta aparte, el cambio sería una transición de
/// página y no la tarjeta "abriéndose" en su lugar que pidió el usuario.
class BienvenidaScreen extends StatefulWidget {
  const BienvenidaScreen({super.key, this.modoInicial = ModoAcceso.portada});

  final ModoAcceso modoInicial;

  @override
  State<BienvenidaScreen> createState() => _BienvenidaScreenState();
}

class _BienvenidaScreenState extends State<BienvenidaScreen> {
  late ModoAcceso _modo = widget.modoInicial;

  void _ir(ModoAcceso modo) => setState(() => _modo = modo);

  Widget _contenido() {
    switch (_modo) {
      case ModoAcceso.portada:
        return _Portada(
          onIniciarSesion: () => _ir(ModoAcceso.login),
          onRegistrarme: () => _ir(ModoAcceso.registro),
        );
      case ModoAcceso.login:
        return _ConVolver(
          onVolver: () => _ir(ModoAcceso.portada),
          child: FormularioLogin(
            onIrARegistro: () => _ir(ModoAcceso.registro),
            onOlvideContrasena: () => _ir(ModoAcceso.recuperar),
          ),
        );
      case ModoAcceso.registro:
        return _ConVolver(
          onVolver: () => _ir(ModoAcceso.portada),
          child: FormularioRegistro(onIrALogin: () => _ir(ModoAcceso.login)),
        );
      case ModoAcceso.recuperar:
        return _ConVolver(
          onVolver: () => _ir(ModoAcceso.login),
          child: FormularioRecuperar(onVolver: () => _ir(ModoAcceso.login)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sinMovimiento = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      // El botón "atrás" de Android (o del navegador) regresa del
      // formulario a la portada en vez de salirse de la app.
      canPop: _modo == ModoAcceso.portada,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _ir(
            _modo == ModoAcceso.recuperar
                ? ModoAcceso.login
                : ModoAcceso.portada,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const FondoAcceso(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: _modo == ModoAcceso.portada ? 620 : 520,
                    ),
                    // AnimatedSize hace que el espacio crezca/encoja con
                    // suavidad mientras el AnimatedSwitcher cruza el
                    // contenido — juntos dan el efecto de que la tarjeta
                    // "se abre" desde donde estaban los botones.
                    child: AnimatedSize(
                      duration: sinMovimiento
                          ? Duration.zero
                          : const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      child: AnimatedSwitcher(
                        duration: sinMovimiento
                            ? Duration.zero
                            : const Duration(milliseconds: 520),
                        reverseDuration: sinMovimiento
                            ? Duration.zero
                            : const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: _transicion,
                        layoutBuilder: (actual, anteriores) => Stack(
                          alignment: Alignment.center,
                          children: [...anteriores, ?actual],
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_modo),
                          child: _contenido(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// La misma curva sirve de entrada (0 → 1) y de salida (1 → 0): lo que
  /// entra crece, se aclara y se enfoca; lo que sale se encoge un poco, se
  /// desvanece y se desenfoca.
  static Widget _transicion(Widget child, Animation<double> animacion) {
    return AnimatedBuilder(
      animation: animacion,
      child: child,
      builder: (context, child) {
        final t = animacion.value;
        final desenfoque = (1 - t) * 14;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.9 + 0.1 * t,
            // Crece desde abajo, que es donde estaban los botones de la
            // portada.
            alignment: const Alignment(0, 0.35),
            child: ImageFiltered(
              enabled: desenfoque > 0.05,
              imageFilter: ImageFilter.blur(
                sigmaX: desenfoque,
                sigmaY: desenfoque,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Tarjeta de vidrio con una flecha discreta en la esquina para regresar.
class _ConVolver extends StatelessWidget {
  const _ConVolver({required this.onVolver, required this.child});

  final VoidCallback onVolver;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TarjetaAcceso(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          // --- Botón "←" (esquina): regresa a la pantalla anterior ---
          Positioned(
            top: -18,
            left: -16,
            child: IconButton(
              tooltip: 'Regresar',
              onPressed: onVolver,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo primero que se ve al entrar: el logo, la promesa de la app y los dos
/// botones. Cada elemento entra uno tras otro, pasando de desenfocado a
/// nítido.
class _Portada extends StatelessWidget {
  const _Portada({required this.onIniciarSesion, required this.onRegistrarme});

  final VoidCallback onIniciarSesion;
  final VoidCallback onRegistrarme;

  @override
  Widget build(BuildContext context) {
    final angosto = MediaQuery.sizeOf(context).width < 600;
    final sinMovimiento = MediaQuery.disableAnimationsOf(context);

    final titulo = AppTextStyles.display.copyWith(
      fontSize: angosto ? 44 : 64,
      height: 1.05,
      letterSpacing: angosto ? -1.4 : -2.2,
    );

    // --- Botón "Iniciar sesión" (abre la tarjeta con el formulario de login) ---
    Widget botonLogin = GradientButton(
      label: 'Iniciar sesión',
      icon: Icons.arrow_forward_rounded,
      onPressed: onIniciarSesion,
    );
    if (!sinMovimiento) {
      // Un destello que cruza el botón cada pocos segundos, para invitar
      // a tocarlo sin moverlo de lugar.
      botonLogin = botonLogin
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
            delay: 2800.ms,
            duration: 1400.ms,
            color: const Color(0x66FFFFFF),
          );
    }

    // --- Botón "Registrarme" (abre la tarjeta con el formulario de registro) ---
    final botonRegistro = BotonVidrio(
      label: 'Registrarme',
      onPressed: onRegistrarme,
    );

    final botones = angosto
        ? Column(
            children: [botonLogin, const SizedBox(height: 14), botonRegistro],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 230, child: botonLogin),
              const SizedBox(width: 16),
              SizedBox(width: 230, child: botonRegistro),
            ],
          );

    final elementos = <Widget>[
      const LogoNeroMoney(tamano: 30),
      const SizedBox(height: 32),
      Text.rich(
        TextSpan(
          style: titulo,
          children: [
            const TextSpan(text: 'Tu dinero,\n'),
            TextSpan(
              text: 'en orden.',
              style: TextStyle(
                foreground: Paint()
                  ..shader = const LinearGradient(
                    colors: [
                      AppColors.primaryCyan,
                      AppColors.secondaryVioletTint,
                    ],
                  ).createShader(const Rect.fromLTWH(0, 0, 320, 80)),
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      Text(
        'Registra tus gastos e ingresos con solo decirlo.\n'
        'Tu asistente de IA se encarga del resto.',
        style: AppTextStyles.bodyLg.copyWith(
          color: AppColors.textSecondary,
          fontSize: angosto ? 16 : 18,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 44),
      botones,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: sinMovimiento
          ? elementos
          : elementos
                .animate(delay: 250.ms, interval: 110.ms)
                .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                .blurXY(
                  begin: 12,
                  end: 0,
                  duration: 700.ms,
                  curve: Curves.easeOut,
                )
                .slideY(
                  begin: 0.25,
                  end: 0,
                  duration: 700.ms,
                  curve: Curves.easeOutCubic,
                ),
    );
  }
}
