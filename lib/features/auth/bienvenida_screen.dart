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

class _BienvenidaScreenState extends State<BienvenidaScreen>
    with SingleTickerProviderStateMixin {
  late ModoAcceso _modo = widget.modoInicial;

  // --- La transformación botón ↔ tarjeta (como los botones "+" de la app,
  // ver BotonConPanel; pedido explícito del usuario) ---
  final _llaveFondo = GlobalKey();
  final _llaveArea = GlobalKey();
  final _llavePortada = GlobalKey();
  final _llaveLogin = GlobalKey();
  final _llaveRegistro = GlobalKey();

  /// 0 = la forma está en el botón; 1 = es la tarjeta completa.
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    reverseDuration: const Duration(milliseconds: 340),
    value: 1,
  );
  late final _curva = CurvedAnimation(
    parent: _morph,
    // Con un poco de rebote al abrir; sin rebote al cerrar.
    curve: const Cubic(0.3, 1.25, 0.5, 1),
    reverseCurve: Curves.easeInCubic,
  );

  /// Dónde estaban los botones de la portada (para regresar a ellos) y de
  /// qué color es cada uno.
  final _botones = <ModoAcceso, Rect>{};
  static const _colorVidrio = Color(0xFF1B2232);
  Rect? _tarjeta;

  /// true mientras la forma se estira o se encoge: los cambios de la
  /// portada a la tarjeta son instantáneos porque la animación es la forma.
  bool _transformando = false;

  /// Al regresar de la tarjeta, la portada no repite su entrada: el botón
  /// tiene que estar justo donde terminó la forma.
  bool _animarPortada = true;

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  void _ir(ModoAcceso modo) => setState(() => _modo = modo);

  Rect? _rectDe(GlobalKey llave) {
    final caja = llave.currentContext?.findRenderObject() as RenderBox?;
    final fondo = _llaveFondo.currentContext?.findRenderObject() as RenderBox?;
    if (caja == null || fondo == null || !caja.hasSize) return null;
    return caja.localToGlobal(Offset.zero, ancestor: fondo) & caja.size;
  }

  /// Portada → tarjeta: el botón tocado se estira hasta ser la tarjeta.
  Future<void> _abrir(ModoAcceso modo) async {
    final login = _rectDe(_llaveLogin);
    final registro = _rectDe(_llaveRegistro);
    if (MediaQuery.disableAnimationsOf(context) ||
        login == null ||
        registro == null) {
      _ir(modo);
      return;
    }
    _botones
      ..[ModoAcceso.login] = login
      ..[ModoAcceso.registro] = registro;
    setState(() {
      _modo = modo;
      _tarjeta = null;
      _transformando = true;
      _morph.value = 0;
    });
    // El tamaño de la tarjeta se conoce hasta que se dibuja.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final tarjeta = _rectDe(_llaveArea);
    if (tarjeta == null) {
      setState(() {
        _transformando = false;
        _morph.value = 1;
      });
      return;
    }
    setState(() => _tarjeta = tarjeta);
    await _morph.forward();
    if (mounted) setState(() => _transformando = false);
  }

  /// Tarjeta → portada: la tarjeta se encoge de vuelta a su botón.
  Future<void> _volverAPortada() async {
    final tarjeta = _rectDe(_llaveArea);
    final boton =
        _botones[_modo == ModoAcceso.registro
            ? ModoAcceso.registro
            : ModoAcceso.login];
    if (MediaQuery.disableAnimationsOf(context) ||
        tarjeta == null ||
        boton == null) {
      _ir(ModoAcceso.portada);
      return;
    }
    setState(() {
      _tarjeta = tarjeta;
      _transformando = true;
      // La portada reaparece (desvaneciéndose de regreso) mientras la forma
      // se encoge; su entrada escalonada no se repite.
      _animarPortada = false;
    });
    await _morph.reverse();
    if (!mounted) return;
    // Todo en un mismo cambio: se va la tarjeta, se quita la forma y la
    // portada queda sola, ya opaca, con el botón donde terminó la forma.
    // (Antes, restablecer la animación con la tarjeta todavía en pantalla
    // la volvía a mostrar completa por un instante.)
    setState(() {
      _modo = ModoAcceso.portada;
      _transformando = false;
      _morph.value = 1;
    });
  }

  Widget _contenido() {
    switch (_modo) {
      // La portada vive en su propia capa (ver build).
      case ModoAcceso.portada:
        return const SizedBox.shrink();
      case ModoAcceso.login:
        return _ConVolver(
          onVolver: _volverAPortada,
          child: FormularioLogin(
            onIrARegistro: () => _ir(ModoAcceso.registro),
            onOlvideContrasena: () => _ir(ModoAcceso.recuperar),
          ),
        );
      case ModoAcceso.registro:
        return _ConVolver(
          onVolver: _volverAPortada,
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
    final enPortada = _modo == ModoAcceso.portada;
    return PopScope(
      // El botón "atrás" de Android (o del navegador) regresa del
      // formulario a la portada en vez de salirse de la app.
      canPop: enPortada,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _transformando) return;
        if (_modo == ModoAcceso.recuperar) {
          _ir(ModoAcceso.login);
        } else {
          _volverAPortada();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        // La portada y la tarjeta van en capas separadas, cada una centrada
        // por su cuenta. Cuando compartían un AnimatedSwitcher, por un
        // cuadro convivían en el mismo contenedor: la portada se centraba
        // en el alto de la tarjeta (aparecía más abajo y brincaba) y la
        // tarjeta que salía se veía como un "fantasma" encima (lo reportó
        // el usuario con video).
        body: Stack(
          key: _llaveFondo,
          fit: StackFit.expand,
          children: [
            const FondoAcceso(),
            // --- La forma que pasa de botón a tarjeta (y de regreso) ---
            AnimatedBuilder(
              animation: _morph,
              builder: (context, _) => _forma(),
            ),
            // --- Portada: se desvanece al abrir y reaparece al cerrar ---
            if (enPortada || _transformando)
              _capa(
                llave: const ValueKey('capa-portada'),
                anchoMaximo: 620,
                child: AnimatedBuilder(
                  animation: _morph,
                  child: KeyedSubtree(
                    key: _llavePortada,
                    child: _Portada(
                      llaveLogin: _llaveLogin,
                      llaveRegistro: _llaveRegistro,
                      animar: _animarPortada,
                      onIniciarSesion: () => _abrir(ModoAcceso.login),
                      onRegistrarme: () => _abrir(ModoAcceso.registro),
                    ),
                  ),
                  builder: (context, hijo) => IgnorePointer(
                    ignoring: !enPortada,
                    child: Opacity(
                      opacity: enPortada
                          ? 1
                          : 1 - const Interval(0, 0.5).transform(_morph.value),
                      child: hijo,
                    ),
                  ),
                ),
              ),
            // --- Tarjeta con el formulario ---
            if (!enPortada)
              _capa(
                llave: const ValueKey('capa-tarjeta'),
                anchoMaximo: 520,
                // AnimatedSize: entre formularios (login ↔ registro) la
                // tarjeta cambia de alto con suavidad.
                child: AnimatedSize(
                  key: _llaveArea,
                  // 1 ms y no cero: con cero, AnimatedSize termina su
                  // animación dentro de su propio layout y Flutter lo marca
                  // como error.
                  duration: sinMovimiento || _transformando
                      ? const Duration(milliseconds: 1)
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
                      child: _apareciendo(_contenido()),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Una capa centrada con scroll (para pantallas bajas o el teclado).
  /// Con llave: así Flutter no confunde la capa de la portada con la de la
  /// tarjeta cuando una aparece o desaparece.
  Widget _capa({
    required Key llave,
    required double anchoMaximo,
    required Widget child,
  }) {
    return SafeArea(
      key: llave,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: anchoMaximo),
            child: child,
          ),
        ),
      ),
    );
  }

  /// La forma que se estira del botón a la tarjeta. Solo existe mientras
  /// dura la transformación.
  Widget _forma() {
    final tarjeta = _tarjeta;
    final boton =
        _botones[_modo == ModoAcceso.registro
            ? ModoAcceso.registro
            : ModoAcceso.login];
    if (!_transformando || tarjeta == null || boton == null) {
      return const SizedBox.shrink();
    }
    final t = _curva.value;
    final avance = t.clamp(0.0, 1.0);
    final rect = Rect.lerp(boton, tarjeta, t)!;
    final colorBoton = _modo == ModoAcceso.registro
        ? _colorVidrio
        : AppColors.acento;
    // Al llegar se desvanece y queda la tarjeta de vidrio de verdad.
    final opacidad = avance < 0.85 ? 1.0 : (1 - avance) / 0.15;
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacidad,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.lerp(
                colorBoton,
                const Color(0xFF141A28),
                (avance * 1.8).clamp(0.0, 1.0),
              ),
              borderRadius: BorderRadius.circular(
                boton.height / 2 + (28 - boton.height / 2) * avance,
              ),
              border: Border.all(
                color: AppColors.glassStrokeHighlight.withValues(alpha: avance),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// El formulario aparece desenfocado y se enfoca en la segunda mitad de
  /// la transformación (y al revés al cerrar).
  Widget _apareciendo(Widget hijo) {
    return AnimatedBuilder(
      animation: _morph,
      child: hijo,
      builder: (context, hijo) {
        final v = const Interval(
          0.4,
          1,
          curve: Curves.easeOut,
        ).transform(_morph.value);
        final desenfoque = (1 - v) * 10;
        return Opacity(
          opacity: v,
          child: ImageFiltered(
            enabled: desenfoque > 0.05,
            imageFilter: ImageFilter.blur(
              sigmaX: desenfoque,
              sigmaY: desenfoque,
            ),
            child: hijo,
          ),
        );
      },
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
              icon: Icon(
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
  const _Portada({
    required this.llaveLogin,
    required this.llaveRegistro,
    required this.animar,
    required this.onIniciarSesion,
    required this.onRegistrarme,
  });

  /// Para saber dónde están los botones: de ahí sale la tarjeta.
  final GlobalKey llaveLogin;
  final GlobalKey llaveRegistro;

  /// false al regresar de la tarjeta: la entrada no se repite.
  final bool animar;
  final VoidCallback onIniciarSesion;
  final VoidCallback onRegistrarme;

  @override
  Widget build(BuildContext context) {
    final angosto = MediaQuery.sizeOf(context).width < 600;
    final sinMovimiento = MediaQuery.disableAnimationsOf(context) || !animar;

    final titulo = AppTextStyles.display.copyWith(
      fontSize: angosto ? 44 : 64,
      height: 1.05,
      letterSpacing: angosto ? -1.4 : -2.2,
    );

    // --- Botón "Iniciar sesión" (abre la tarjeta con el formulario de login) ---
    Widget botonLogin = KeyedSubtree(
      key: llaveLogin,
      child: GradientButton(
        label: 'Iniciar sesión',
        icon: Icons.arrow_forward_rounded,
        onPressed: onIniciarSesion,
      ),
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
    final botonRegistro = KeyedSubtree(
      key: llaveRegistro,
      child: BotonVidrio(label: 'Registrarme', onPressed: onRegistrarme),
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
                  ..shader = LinearGradient(
                    colors: [AppColors.acento, AppColors.secundarioClaro],
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
