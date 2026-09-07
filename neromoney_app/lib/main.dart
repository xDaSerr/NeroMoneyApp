import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  // Requerido antes de tocar cualquier plugin nativo (Firebase incluido).
  WidgetsFlutterBinding.ensureInitialized();
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NeroMoney',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
