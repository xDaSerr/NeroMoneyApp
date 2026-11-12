import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/router/app_shell.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/controlador_tema.dart';
import 'core/theme/tema_app.dart';
import 'core/widgets/fondo_tema.dart';
import 'features/auth/providers/auth_providers.dart';
import 'firebase_options.dart';

void main() async {
  // Requerido antes de tocar cualquier plugin nativo (Firebase incluido).
  WidgetsFlutterBinding.ensureInitialized();
  // Las variantes usadas vienen en assets; evita descargas y cambios de
  // tipografía tardíos al estrenar la app o usarla sin conexión.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final familia in ['Outfit', 'JetBrainsMono']) {
      yield LicenseEntryWithLineBreaks([
        familia,
      ], await rootBundle.loadString('assets/fonts/$familia-OFL.txt'));
    }
  });
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Sin esto, Android pinta su propia franja opaca detrás del gesto de
  // inicio (el "home indicator") — se veía como un rectángulo ajeno detrás
  // de la píldora flotante de navegación (ver AppShell). Con la barra de
  // navegación del sistema transparente y en modo edge-to-edge, esa zona
  // deja de pintarse aparte y se ve el contenido real de la app detrás,
  // que es justo el efecto flotante que se pidió.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Los colores de las barras del sistema dependen del tema; los aplica
  // NeroMoneyApp al arrancar y en cada cambio de tema.

  // El tema guardado en el dispositivo, para que el primer cuadro ya salga
  // con el color del usuario (ver ControladorTema).
  await ControladorTema.instancia.cargarGuardado();

  // ProviderScope habilita Riverpod (manejo de estado) en toda la app.
  runApp(const ProviderScope(child: NeroMoneyApp()));
}

class NeroMoneyApp extends ConsumerStatefulWidget {
  const NeroMoneyApp({super.key});

  @override
  ConsumerState<NeroMoneyApp> createState() => _NeroMoneyAppState();
}

class _NeroMoneyAppState extends ConsumerState<NeroMoneyApp> {
  // Las pantallas internas (Stitch) son de teléfono. En una ventana ancha,
  // las de un solo paso (agregar movimiento, transferir, perfil...) se
  // centran en una columna; las pestañas usan el diseño de escritorio de
  // AppShell y el acceso, su propia pantalla completa.
  static const double _anchoTelefono = 480;
  static const double _anchoColumnaEscritorio = 560;

  TemaApp? _temaAplicado;

  @override
  void initState() {
    super.initState();
    ControladorTema.instancia.addListener(_alCambiarTema);
  }

  @override
  void dispose() {
    ControladorTema.instancia.removeListener(_alCambiarTema);
    super.dispose();
  }

  /// El acceso (portada y formularios) siempre usa la paleta Negra: está
  /// diseñado sobre la imagen de fondo cian/violeta.
  TemaApp get _temaEfectivo => ref.read(currentUidProvider) == null
      ? TemaApp.negro
      : ControladorTema.instancia.tema;

  void _alCambiarTema() {
    if (_aplicar(_temaEfectivo)) {
      _reconstruirTodo();
      setState(() {});
    }
  }

  bool _aplicar(TemaApp tema) {
    if (tema == _temaAplicado) return false;
    _temaAplicado = tema;
    final paleta = PaletaTema.de(tema);
    AppColors.aplicar(paleta);
    // Íconos de la barra de estado legibles sobre el fondo del tema.
    final iconos = paleta.esClaro ? Brightness.dark : Brightness.light;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: iconos,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconos,
        statusBarBrightness: paleta.brillo,
      ),
    );
    return true;
  }

  /// Los colores se leen de AppColors al construir cada widget, y los
  /// widgets `const` no se reconstruyen solos: al cambiar de tema se marca
  /// todo el árbol para que vuelva a leerlos. Cambiar de tema es raro
  /// (onboarding, Perfil), así que el costo no importa.
  void _reconstruirTodo() {
    void marcar(Element elemento) {
      elemento.markNeedsBuild();
      elemento.visitChildren(marcar);
    }

    (context as Element).visitChildren(marcar);
  }

  @override
  Widget build(BuildContext context) {
    // Al iniciar/cerrar sesión cambia el tema efectivo (acceso = Negro). Las
    // pantallas se reemplazan en ese mismo momento, y lo que sobreviva se
    // vuelve a pintar al terminar el cuadro.
    ref.watch(currentUidProvider);
    final primeraVez = _temaAplicado == null;
    if (_aplicar(_temaEfectivo) && !primeraVez) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reconstruirTodo();
      });
    }

    return MaterialApp.router(
      title: 'NeroMoney',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.actual,
      routerConfig: appRouter,
      // Se escucha al router porque la distribución depende de la ruta.
      builder: (context, child) => ListenableBuilder(
        listenable: appRouter.routerDelegate,
        builder: (context, _) => _distribuir(context, child!),
      ),
    );
  }

  Widget _distribuir(BuildContext context, Widget child) {
    final mq = MediaQuery.of(context);
    final ruta = appRouter.routerDelegate.currentConfiguration.uri.path;
    final ventana = mq.size.width;
    final acceso = esRutaDeAcceso(ruta);
    final escritorioConPestanas =
        ventana >= anchoEscritorio && esRutaDePestana(ruta);
    final pantallaCompleta =
        acceso || ventana <= _anchoTelefono || escritorioConPestanas;
    final ancho = pantallaCompleta
        ? ventana
        : (ventana >= anchoEscritorio
              ? _anchoColumnaEscritorio
              : _anchoTelefono);
    final tema = Theme.of(context);

    // OJO: la estructura de widgets es SIEMPRE la misma, solo cambian sus
    // valores. Si el Navigator (child) cambiara de lugar en el árbol al
    // pasar de una ruta a otra, Flutter lo reconstruiría desde cero y se
    // perdería el estado de la pantalla (pasó: la tarjeta de inicio de
    // sesión volvía sola a la portada al cargar, cuando la ruta pasaba de
    // "/" a "/login" y un Container agregaba/quitaba su decoración).
    return Stack(
      fit: StackFit.expand,
      children: [
        const FondoTema(),
        Center(
          child: SizedBox(
            width: ancho,
            child: ColoredBox(
              // En escritorio las pestañas dejan ver el FondoTema (con sus
              // resplandores); la columna y el teléfono usan el fondo liso.
              color: escritorioConPestanas || acceso
                  ? Colors.transparent
                  : AppColors.canvas,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: pantallaCompleta
                      ? null
                      : Border.symmetric(
                          vertical: BorderSide(
                            color: AppColors.glassStrokeStandard,
                          ),
                        ),
                ),
                // El tamaño se reescribe en MediaQuery para que todo lo que
                // mide la pantalla (diálogos, panel de voz, barra flotante)
                // calcule con el ancho de la columna, no con el de la ventana.
                child: MediaQuery(
                  data: mq.copyWith(size: Size(ancho, mq.size.height)),
                  child: Theme(
                    data: escritorioConPestanas
                        ? tema.copyWith(
                            scaffoldBackgroundColor: Colors.transparent,
                          )
                        : tema,
                    child: ClipRect(child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
