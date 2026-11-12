import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neromoney_app/core/router/app_shell.dart';
import 'package:neromoney_app/core/theme/app_colors.dart';
import 'package:neromoney_app/core/theme/app_theme.dart';
import 'package:neromoney_app/core/theme/controlador_tema.dart';
import 'package:neromoney_app/core/theme/tema_app.dart';
import 'package:neromoney_app/core/widgets/escucha_segura.dart';
import 'package:neromoney_app/core/widgets/marco_escritorio.dart';
import 'package:neromoney_app/features/accounts/accounts_screen.dart';
import 'package:neromoney_app/features/accounts/data/cuenta.dart';
import 'package:neromoney_app/features/accounts/providers/cuentas_providers.dart';
import 'package:neromoney_app/features/assistant/data/controlador_asistente.dart';
import 'package:neromoney_app/features/assistant/providers/controlador_asistente_provider.dart';
import 'package:neromoney_app/features/assistant/widgets/pregunta_nombre_asistente.dart';
import 'package:neromoney_app/features/auth/providers/auth_providers.dart';
import 'package:neromoney_app/features/home/home_screen.dart';
import 'package:neromoney_app/features/home/widgets/inicio_escritorio.dart';
import 'package:neromoney_app/features/onboarding/data/perfil_usuario.dart';
import 'package:neromoney_app/features/onboarding/onboarding_flow_screen.dart';
import 'package:neromoney_app/features/onboarding/widgets/muestra_tema.dart';
import 'package:neromoney_app/features/onboarding/providers/perfil_providers.dart';
import 'package:neromoney_app/features/profile/profile_screen.dart';
import 'package:neromoney_app/features/reminders/providers/recordatorios_sync_provider.dart';
import 'package:neromoney_app/features/reports/reports_screen.dart';
import 'package:neromoney_app/features/transactions/data/transaccion.dart';
import 'package:neromoney_app/features/transactions/movements_screen.dart';
import 'package:neromoney_app/features/transactions/providers/transacciones_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/escenario_rendimiento.dart' show MotorSimulado;

/// El Inicio de escritorio (menú lateral + dos columnas) se arma en los 8
/// temas sin desbordes ni errores; también el Inicio de teléfono en el tema
/// claro, el paso de color del onboarding y la pregunta del nombre. Datos en memoria: no inicia sesión ni
/// toca Firebase.
///
/// Para revisar el diseño a ojo:
///   flutter test test/escritorio_temas_test.dart --dart-define=CAPTURAS=CARPETA
/// guarda un PNG por pantalla en CARPETA.
const _carpetaCapturas = String.fromEnvironment('CAPTURAS');

final _cuentas = [
  const Cuenta(
    id: 'efectivo',
    nombre: 'Efectivo',
    tipo: TipoCuenta.efectivo,
    saldoActual: 8870,
  ),
  const Cuenta(
    id: 'rappi',
    nombre: 'Rappi Card',
    tipo: TipoCuenta.credito,
    saldoActual: 4068.28,
    limiteCredito: 7000,
    ultimos4Digitos: '0097',
  ),
  const Cuenta(
    id: 'spin',
    nombre: 'Spin Oxxo',
    tipo: TipoCuenta.debito,
    saldoActual: 17472.42,
    ultimos4Digitos: '5643',
  ),
];

List<Transaccion> _movimientos() {
  final hoy = DateTime.now();
  Transaccion gasto(String id, double monto, String categoria, String desc) =>
      Transaccion(
        id: id,
        monto: monto,
        tipo: TipoTransaccion.gasto,
        categoria: categoria,
        descripcion: desc,
        cuentaId: 'efectivo',
        fecha: DateTime(hoy.year, hoy.month, 1, 12),
      );
  return [
    gasto('a', 500, 'Compras', 'Amazon'),
    gasto('b', 400, 'Compras', 'Amazon'),
    gasto('c', 100, 'Alimentación', 'Cafetería'),
  ];
}

Future<void> _cargarFuentes() async {
  // Sin esto, flutter test dibuja el texto con una fuente de cuadritos.
  Future<void> cargar(String familia, List<String> archivos) async {
    final cargador = FontLoader(familia);
    for (final archivo in archivos) {
      cargador.addFont(
        Future.value(ByteData.sublistView(await File(archivo).readAsBytes())),
      );
    }
    await cargador.load();
  }

  final flutterRaiz = Platform.environment['FLUTTER_ROOT'];
  await cargar('Outfit', [
    'assets/fonts/Outfit-Regular.ttf',
    'assets/fonts/Outfit-SemiBold.ttf',
    'assets/fonts/Outfit-Bold.ttf',
  ]);
  await cargar('JetBrainsMono', ['assets/fonts/JetBrainsMono-Medium.ttf']);
  if (flutterRaiz != null) {
    final iconos = File(
      '$flutterRaiz/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
    if (iconos.existsSync()) await cargar('MaterialIcons', [iconos.path]);
  }
}

/// Monta las 5 pestañas reales del shell con Inicio, en memoria, al tamaño
/// dado. Devuelve la llave del RepaintBoundary para poder capturarlo.
Future<GlobalKey> _montarInicio(
  WidgetTester tester,
  TemaApp tema,
  Size tamano,
) async {
  SharedPreferences.setMockInitialValues({});
  AppColors.aplicar(PaletaTema.de(tema));
  addTearDown(() => AppColors.aplicar(PaletaTema.de(TemaApp.negro)));
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final asistente = ControladorAsistente(
    motor: MotorSimulado(),
    enviar: (_, _) async => throw StateError('No enviar en la prueba'),
    completar: (_, _) async => throw StateError('No registrar'),
    hablar: (_) async {},
    callar: () async {},
  );
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          for (final ruta in [
            '/home',
            '/movements',
            '/assistant',
            '/accounts',
            '/profile',
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: ruta,
                  builder: (_, _) => switch (ruta) {
                    '/home' => const HomeScreen(),
                    '/movements' => const MovementsScreen(),
                    '/accounts' => const AccountsScreen(),
                    '/profile' => const ProfileScreen(),
                    _ => const Scaffold(body: SizedBox()),
                  },
                ),
              ],
            ),
        ],
      ),
      GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
    ],
  );
  _router = router;
  final perfil = PerfilUsuario.vacio.copyWith(
    apodo: 'xDaSerr',
    onboardingCompletado: true,
    tema: tema,
  );
  final llave = GlobalKey();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('prueba-local'),
        authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
        cuentasProvider.overrideWith((ref) => Stream.value(_cuentas)),
        transaccionesProvider.overrideWith(
          (ref) => Stream.value(_movimientos()),
        ),
        transaccionesPorRangoProvider.overrideWith(
          (ref, rango) => Stream.value(_movimientos()),
        ),
        perfilProvider.overrideWith((ref) => Stream.value(perfil)),
        recordatoriosSyncProvider.overrideWith((ref) {}),
        controladorAsistenteProvider.overrideWithValue(asistente),
      ],
      child: RepaintBoundary(
        key: llave,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.actual,
          routerConfig: router,
          builder: (context, child) => EscuchaSegura(
            escuchar: router.routerDelegate,
            builder: (context) => MarcoEscritorio(
              activo: tamano.width >= anchoEscritorio,
              ruta: router.routerDelegate.currentConfiguration.uri.path,
              onIr: router.go,
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  await _avanzar(tester);
  return llave;
}

late GoRouter _router;

/// Las animaciones de entrada arrancan en un cuadro y avanzan en los
/// siguientes: un solo pump largo las deja en su primer instante.
Future<void> _avanzar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _capturar(
  WidgetTester tester,
  GlobalKey llave,
  String nombre,
) async {
  if (_carpetaCapturas.isEmpty) return;
  await tester.runAsync(() async {
    final limite =
        llave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagen = await limite.toImage();
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    await File('$_carpetaCapturas/$nombre.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(_cargarFuentes);

  for (final tema in TemaApp.values) {
    testWidgets('Inicio de escritorio en tema ${tema.etiqueta}', (
      tester,
    ) async {
      final llave = await _montarInicio(tester, tema, const Size(1600, 1000));

      expect(tester.takeException(), isNull);
      expect(find.byType(InicioEscritorio), findsOneWidget);
      expect(find.text('Hola, xDaSerr 👋'), findsOneWidget);
      expect(find.text(r'$26,342.42'), findsOneWidget);
      await _capturar(tester, llave, 'escritorio_${tema.name}');
    });
  }

  testWidgets('Secciones de escritorio y transición desde el menú', (
    tester,
  ) async {
    final llave = await _montarInicio(
      tester,
      TemaApp.negro,
      const Size(1600, 1000),
    );
    for (final ruta in ['/movements', '/accounts', '/reports', '/profile']) {
      _router.go(ruta);
      await _avanzar(tester);
      expect(tester.takeException(), isNull, reason: ruta);
      await _capturar(tester, llave, 'seccion${ruta.replaceAll('/', '_')}');
    }
    expect(find.text('Mi perfil'), findsOneWidget);

    // A media animación: la sección sale del botón "Cuentas" del menú, con
    // el contorno de luz alrededor.
    _router.go('/accounts');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    await _capturar(tester, llave, 'transicion_cuentas');
    await _avanzar(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Cuentas y bolsillos'), findsOneWidget);
  });

  testWidgets('Inicio de teléfono en tema Blanco', (tester) async {
    final llave = await _montarInicio(
      tester,
      TemaApp.blanco,
      const Size(400, 860),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(InicioEscritorio), findsNothing);
    expect(find.text('Hola, xDaSerr 👋'), findsOneWidget);
    await _capturar(tester, llave, 'telefono_blanco');
  });

  testWidgets('Onboarding: el paso 2 muestra los 8 colores', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ControladorTema.instancia.cambiar(TemaApp.morado);
    AppColors.aplicar(PaletaTema.de(TemaApp.morado));
    addTearDown(() {
      ControladorTema.instancia.cambiar(TemaApp.negro);
      AppColors.aplicar(PaletaTema.de(TemaApp.negro));
    });
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final llave = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUidProvider.overrideWithValue('prueba-local')],
        child: RepaintBoundary(
          key: llave,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.actual,
            home: const OnboardingFlowScreen(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continuar'));
    await _avanzar(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Elige el color de tu app'), findsOneWidget);
    expect(find.byType(MuestraTema), findsNWidgets(TemaApp.values.length));
    await _capturar(tester, llave, 'onboarding_color');
  });

  testWidgets('El asistente pregunta cómo quiere que lo llamen', (
    tester,
  ) async {
    AppColors.aplicar(PaletaTema.de(TemaApp.azul));
    addTearDown(() => AppColors.aplicar(PaletaTema.de(TemaApp.negro)));
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final llave = GlobalKey();
    String? elegido;

    await tester.pumpWidget(
      RepaintBoundary(
        key: llave,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.actual,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async =>
                      elegido = await preguntarNombreAsistente(context),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await _avanzar(tester);
    expect(find.text('¿Cómo me quieres llamar?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Nova');
    await tester.pump();
    await _capturar(tester, llave, 'pregunta_nombre');

    await tester.tap(find.text('Llámame Nova'));
    await _avanzar(tester);
    expect(elegido, 'Nova');
    expect(tester.takeException(), isNull);
  });
}
