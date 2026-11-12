import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
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
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // ProviderScope habilita Riverpod (manejo de estado) en toda la app.
  runApp(const ProviderScope(child: NeroMoneyApp()));
}

class NeroMoneyApp extends StatelessWidget {
  const NeroMoneyApp({super.key});

  // Todo el diseño (Stitch) es de teléfono. En una pantalla ancha (la
  // versión web abierta en una PC, o una tablet) estirarlo a todo lo ancho
  // dejaba campos y tarjetas kilométricos — se centra una "columna" de
  // teléfono en su lugar, como WhatsApp Web.
  static const double _anchoMaximo = 480;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NeroMoney',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        if (mq.size.width <= _anchoMaximo) return child!;
        return ColoredBox(
          color: const Color(0xFF05070B),
          child: Center(
            child: Container(
              width: _anchoMaximo,
              color: AppColors.canvas,
              // foregroundDecoration (no decoration) para que el borde no
              // le quite píxeles al ancho que se reporta abajo.
              foregroundDecoration: const BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(color: AppColors.glassStrokeStandard),
                ),
              ),
              // El tamaño se reescribe en MediaQuery para que todo lo que
              // mide la pantalla (diálogos, panel de voz, barra flotante)
              // calcule con el ancho de la columna, no con el de la ventana.
              child: MediaQuery(
                data: mq.copyWith(size: Size(_anchoMaximo, mq.size.height)),
                child: ClipRect(child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}
