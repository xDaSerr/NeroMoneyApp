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
import 'package:neromoney_app/core/widgets/observador_modales.dart';
import 'package:neromoney_app/features/accounts/accounts_screen.dart';
import 'package:neromoney_app/features/accounts/data/cuenta.dart';
import 'package:neromoney_app/features/accounts/providers/cuentas_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:neromoney_app/features/accounts/account_detail_screen.dart';
import 'package:neromoney_app/features/profile/personalizar_asistente_screen.dart';
import 'package:neromoney_app/features/assistant/assistant_chat_screen.dart';
import 'package:neromoney_app/features/assistant/data/controlador_asistente.dart';
import 'package:neromoney_app/features/assistant/data/mensaje_chat.dart';
import 'package:neromoney_app/features/assistant/providers/asistente_providers.dart';
import 'package:neromoney_app/features/assistant/providers/controlador_asistente_provider.dart';
import 'package:neromoney_app/features/assistant/widgets/pregunta_nombre_asistente.dart';
import 'package:neromoney_app/features/auth/bienvenida_screen.dart';
import 'package:neromoney_app/features/auth/providers/auth_providers.dart';
import 'package:neromoney_app/features/home/home_screen.dart';
import 'package:neromoney_app/features/home/widgets/inicio_escritorio.dart';
import 'package:neromoney_app/features/onboarding/data/perfil_usuario.dart';
import 'package:neromoney_app/features/onboarding/onboarding_flow_screen.dart';
import 'package:neromoney_app/features/onboarding/widgets/muestra_tema.dart';
import 'package:neromoney_app/features/onboarding/providers/perfil_providers.dart';
import 'package:neromoney_app/features/profile/profile_screen.dart';
import 'package:neromoney_app/features/reminders/providers/recordatorios_sync_provider.dart';
import 'package:neromoney_app/features/analisis/analisis_screen.dart';
import 'package:neromoney_app/features/analisis/data/deteccion.dart';
import 'package:neromoney_app/features/analisis/data/resumen_mensual.dart';
import 'package:neromoney_app/features/analisis/providers/analisis_providers.dart';
import 'package:neromoney_app/core/moneda/conversor_moneda.dart';
import 'package:neromoney_app/core/widgets/fondo_tema.dart';
import 'package:neromoney_app/core/moneda/monedas_providers.dart';
import 'package:neromoney_app/features/planes/data/membresia.dart';
import 'package:neromoney_app/features/respaldos/respaldos_screen.dart';
import 'package:neromoney_app/features/planes/planes_screen.dart';
import 'package:neromoney_app/features/planes/providers/planes_providers.dart';
import 'package:neromoney_app/features/presupuestos/data/planeacion.dart';
import 'package:neromoney_app/features/presupuestos/presupuestos_screen.dart';
import 'package:neromoney_app/features/presupuestos/providers/planeacion_providers.dart';
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

List<MensajeChat> _chat() {
  final hoy = DateTime.now();
  MensajeChat m(
    String id,
    AutorMensaje autor,
    String texto,
    int minuto, {
    Map<String, dynamic>? movimiento,
  }) => MensajeChat(
    id: id,
    autor: autor,
    contenido: texto,
    fecha: DateTime(hoy.year, hoy.month, hoy.day, 9, minuto),
    registrado: movimiento != null,
    movimiento: movimiento,
  );
  return [
    m(
      '1',
      AutorMensaje.asistente,
      'Hola, xDaSerr 👋 ¿Qué quieres registrar o consultar hoy?',
      0,
    ),
    m('2', AutorMensaje.usuario, 'Gasté 100 pesos en un café, en efectivo.', 1),
    m(
      '3',
      AutorMensaje.asistente,
      'Listo, registré tu gasto.',
      1,
      movimiento: {
        'tipo': 'gasto',
        'monto': 100.0,
        'categoria': 'Alimentación',
        'descripcion': 'café',
        'cuentaId': 'efectivo',
        'fecha': Timestamp.fromDate(DateTime(hoy.year, hoy.month, hoy.day)),
      },
    ),
    m('4', AutorMensaje.usuario, '¿Puedo registrar un gasto de otro día?', 2),
    m(
      '5',
      AutorMensaje.asistente,
      'Sí. Dime la fecha, el monto y la cuenta que usaste.',
      2,
    ),
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
  Size tamano, {
  PlanNero plan = PlanNero.gratis,
  List<Cuenta>? cuentas,
  FondoApp? fondo,
}) async {
  SharedPreferences.setMockInitialValues({});
  AppColors.aplicar(
    fondo != null ? PaletaTema.deFondo(fondo) : PaletaTema.de(tema),
  );
  addTearDown(() => AppColors.aplicar(PaletaTema.de(TemaApp.negro)));
  addTearDown(() => ControladorTema.instancia.cambiarFondo(null));
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
    observers: [observadorModales],
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
                    '/assistant' => const AssistantChatScreen(),
                    _ => const Scaffold(body: SizedBox()),
                  },
                  routes: [
                    if (ruta == '/accounts')
                      GoRoute(
                        path: 'detalle',
                        builder: (_, state) => AccountDetailScreen(
                          cuentaId: state.extra as String,
                        ),
                      ),
                  ],
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
    fondo: fondo,
  );
  final llave = GlobalKey();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('prueba-local'),
        authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
        cuentasProvider.overrideWith(
          (ref) => Stream.value(cuentas ?? _cuentas),
        ),
        membresiaProvider.overrideWithValue(AsyncData(Membresia(plan: plan))),
        tiposCambioProvider.overrideWith(
          (ref) async => const {'USD': 1.0, 'MXN': 18.0},
        ),
        transaccionesProvider.overrideWith(
          (ref) => Stream.value(_movimientos()),
        ),
        transaccionesPorCuentaProvider.overrideWith(
          (ref, id) => Stream.value([
            for (final t in _movimientos())
              if (t.cuentaId == id) t,
          ]),
        ),
        mensajesChatProvider.overrideWith((ref) => Stream.value(_chat())),
        borradorPendienteProvider.overrideWith((ref) => Stream.value(null)),
        transaccionesPorRangoProvider.overrideWith(
          (ref, rango) => Stream.value(_movimientos()),
        ),
        perfilProvider.overrideWith((ref) => Stream.value(perfil)),
        recordatoriosSyncProvider.overrideWith((ref) {}),
        controladorAsistenteProvider.overrideWithValue(asistente),
        presupuestosProvider.overrideWith(
          (ref) => Stream.value(const [
            Presupuesto(id: 'a', categoria: 'Alimentación', limite: 700),
            Presupuesto(id: 'b', categoria: 'Transporte', limite: 2000),
          ]),
        ),
        metasProvider.overrideWith(
          (ref) => Stream.value([
            MetaAhorro(
              id: 'm',
              nombre: 'Viaje a Oaxaca',
              objetivo: 15000,
              ahorrado: 4500,
              creada: DateTime(2026, 8, 1),
            ),
          ]),
        ),
      ],
      child: RepaintBoundary(
        key: llave,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.actual,
          routerConfig: router,
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              if (fondo != null) const FondoTema(),
              EscuchaSegura(
                escuchar: router.routerDelegate,
                builder: (context) => MarcoEscritorio(
                  activo: tamano.width >= anchoEscritorio,
                  ruta: router.routerDelegate.currentConfiguration.uri.path,
                  onIr: router.go,
                  child: Theme(
                    data: fondo == null
                        ? Theme.of(context)
                        : Theme.of(context).copyWith(
                            scaffoldBackgroundColor: Colors.transparent,
                          ),
                    child: child!,
                  ),
                ),
              ),
            ],
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

    // El botón "Nuevo movimiento" se transforma en el panel.
    _router.go('/movements');
    await _avanzar(tester);
    await tester.tap(find.text('Nuevo movimiento'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 170));
    await _capturar(tester, llave, 'panel_movimiento_abriendo');
    await _avanzar(tester);
    expect(find.text('Registra un gasto o un ingreso.'), findsOneWidget);
    await _capturar(tester, llave, 'panel_movimiento');
    // "Crear movimiento" sin datos dice qué falta en vez de no hacer nada.
    await tester.tap(find.text('Crear movimiento'));
    await tester.pump();
    expect(find.text('Escribe un monto mayor a 0.'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await _avanzar(tester);
    expect(find.text('Registra un gasto o un ingreso.'), findsNothing);
    expect(tester.takeException(), isNull);

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

  for (final (nombre, tamano) in [
    ('escritorio', const Size(1600, 1000)),
    ('teléfono', const Size(400, 860)),
  ])
    testWidgets('Portada ($nombre): los botones se transforman en la tarjeta', (
      tester,
    ) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final llave = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: RepaintBoundary(
            key: llave,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.actual,
              home: const BienvenidaScreen(),
            ),
          ),
        ),
      );
      await _avanzar(tester);
      await _avanzar(tester);

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      await _capturar(tester, llave, 'acceso_abriendo_${tamano.width.round()}');
      await _avanzar(tester);
      expect(find.text('Bienvenido de nuevo'), findsOneWidget);
      await _capturar(tester, llave, 'acceso_login_${tamano.width.round()}');

      // La flecha regresa: la tarjeta se encoge de vuelta al botón.
      await tester.tap(find.byTooltip('Regresar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await _capturar(tester, llave, 'acceso_cerrando_${tamano.width.round()}');
      await _avanzar(tester);
      expect(find.text('Registrarme'), findsOneWidget);
      expect(find.text('Bienvenido de nuevo'), findsNothing);

      await tester.tap(find.text('Registrarme'));
      await _avanzar(tester);
      expect(find.text('Crea tu cuenta'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

    // En teléfono, "Ingreso" se transforma en el panel ya en modo ingreso.
    await tester.tap(find.text('Ingreso'));
    await _avanzar(tester);
    expect(find.text('Registra un gasto o un ingreso.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capturar(tester, llave, 'panel_telefono');
  });

  testWidgets('Secciones de teléfono con el diseño móvil', (tester) async {
    final llave = await _montarInicio(
      tester,
      TemaApp.negro,
      const Size(400, 860),
    );
    await _capturar(tester, llave, 'movil_inicio');
    for (final (ruta, titulo) in [
      ('/movements', 'Movimientos'),
      ('/accounts', 'Tus bolsillos, organizados.'),
      ('/reports', 'Entiende tu dinero.'),
      ('/profile', 'Haz NeroMoney tuyo.'),
    ]) {
      _router.go(ruta);
      await _avanzar(tester);
      expect(tester.takeException(), isNull, reason: ruta);
      expect(find.text(titulo), findsWidgets, reason: ruta);
      await _capturar(tester, llave, 'movil${ruta.replaceAll('/', '_')}');
    }

    // "+ Nuevo" de Movimientos se transforma en el panel.
    _router.go('/movements');
    await _avanzar(tester);
    await tester.tap(find.text('Nuevo'));
    await _avanzar(tester);
    expect(find.text('Registra un gasto o un ingreso.'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  for (final (nombre, tamano, membresia) in [
    ('telefono_gratis', const Size(400, 860), Membresia.gratis),
    ('escritorio_gratis', const Size(1500, 1000), Membresia.gratis),
    (
      'escritorio_plus_cancelado',
      const Size(1500, 1000),
      Membresia(
        plan: PlanNero.plus,
        cancelaAlFinal: true,
        periodoFin: DateTime(2026, 12, 13),
        tieneCuentaDePago: true,
      ),
    ),
  ]) {
    testWidgets('Planes: $nombre', (tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final llave = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membresiaProvider.overrideWithValue(AsyncData(membresia)),
            usoIAProvider.overrideWithValue(
              AsyncData(UsoIA(mes: _mesActual(), enMes: 4)),
            ),
          ],
          child: RepaintBoundary(
            key: llave,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.actual,
              home: const PlanesScreen(),
            ),
          ),
        ),
      );
      await _avanzar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Elige tu plan'), findsOneWidget);
      if (membresia.plan == PlanNero.gratis) {
        expect(find.textContaining('Te quedan 11 mensajes'), findsOneWidget);
        expect(find.text('Elegir Plus'), findsOneWidget);
        expect(find.text('Elegir Pro'), findsOneWidget);
      } else {
        expect(find.text('Reactivar suscripción'), findsOneWidget);
        expect(find.text('Plan actual'), findsNothing);
        expect(find.text('Cancelar suscripción'), findsNothing);
        expect(find.text('Cambiar a Pro'), findsOneWidget);
        expect(find.textContaining('lo conservas hasta el 13'), findsOneWidget);
        expect(find.text('Administrar suscripción'), findsOneWidget);
      }

      // Anual: cambia el precio y muestra el equivalente mensual.
      await tester.tap(find.text('Anual · ahorra 17%'));
      await _avanzar(tester);
      expect(find.text(r'$14.99'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capturar(tester, llave, 'planes_$nombre');
    });
  }

  for (final (nombre, tamano) in [
    ('telefono', const Size(400, 1500)),
    ('escritorio', const Size(1500, 1000)),
  ]) {
    testWidgets('Presupuestos y metas: $nombre', (tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final llave = GlobalKey();
      final hoy = DateTime.now();
      const presupuestos = [
        Presupuesto(id: 'a', categoria: 'Alimentación', limite: 4000),
        Presupuesto(id: 'b', categoria: 'Ocio', limite: 1200),
        Presupuesto(id: 'c', categoria: 'Transporte', limite: 1500),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membresiaProvider.overrideWithValue(
              const AsyncData(Membresia.gratis),
            ),
            estadosPresupuestoProvider.overrideWithValue(
              AsyncData([
                EstadoPresupuesto(presupuestos[1], 1350),
                EstadoPresupuesto(presupuestos[0], 3400),
                EstadoPresupuesto(presupuestos[2], 420),
              ]),
            ),
            metasProvider.overrideWithValue(
              AsyncData([
                MetaAhorro(
                  id: 'm1',
                  nombre: 'Viaje a Oaxaca',
                  objetivo: 15000,
                  ahorrado: 4500,
                  creada: hoy.subtract(const Duration(days: 92)),
                  fechaLimite: DateTime(hoy.year + 1, 6, 30),
                ),
                MetaAhorro(
                  id: 'm2',
                  nombre: 'Fondo de emergencia',
                  objetivo: 5000,
                  ahorrado: 5000,
                  creada: hoy,
                ),
              ]),
            ),
          ],
          child: RepaintBoundary(
            key: llave,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.actual,
              home: const PresupuestosScreen(),
            ),
          ),
        ),
      );
      await _avanzar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(r'Te pasaste por $150.00'), findsOneWidget);
      expect(find.text(r'Cuidado: te quedan $600.00'), findsOneWidget);
      expect(find.text('¡Meta cumplida! 🎉'), findsOneWidget);
      expect(find.textContaining('A este ritmo llegas en'), findsOneWidget);
      await _capturar(tester, llave, 'presupuestos_$nombre');

      // Gratis con presupuestos: "Agregar" ofrece Plus en vez del formulario.
      await tester.tap(find.text('Agregar').first);
      await _avanzar(tester);
      expect(find.text('Presupuestos ilimitados con Plus'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (nombre, tamano, plan) in [
    ('telefono_gratis', const Size(400, 1500), PlanNero.gratis),
    ('escritorio_plus', const Size(1500, 1100), PlanNero.plus),
  ]) {
    testWidgets('Análisis inteligente: $nombre', (tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final llave = GlobalKey();
      final deteccion = Deteccion(
        recurrentes: [
          CargoRecurrente(
            nombre: 'Gimnasio',
            categoria: 'Salud',
            monto: 650,
            veces: 4,
            ultimaFecha: DateTime(2026, 11, 1),
            proximaFecha: DateTime(2026, 12, 1),
          ),
          CargoRecurrente(
            nombre: 'Netflix',
            categoria: 'Ocio',
            monto: 229,
            veces: 4,
            ultimaFecha: DateTime(2026, 11, 5),
            proximaFecha: DateTime(2026, 12, 5),
          ),
        ],
        hormiga: const [
          GastoHormiga(
            nombre: 'Café',
            categoria: 'Alimentación',
            veces: 12,
            total: 720,
          ),
          GastoHormiga(
            nombre: 'Uber',
            categoria: 'Transporte',
            veces: 5,
            total: 410,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membresiaProvider.overrideWithValue(
              AsyncData(Membresia(plan: plan)),
            ),
            deteccionProvider.overrideWithValue(AsyncData(deteccion)),
            resumenMensualProvider.overrideWith(
              (ref, mes) => Stream.value(
                ResumenMensual(
                  mes: mes,
                  titular: 'Gastaste 12% menos que en octubre',
                  puntos: const [
                    r'Alimentación fue lo más alto: $3,400, casi igual que el mes pasado.',
                    r'Ocio bajó de $2,100 a $1,350.',
                    r'Tus ingresos de $18,000 cubrieron todo y te sobraron $6,200.',
                  ],
                  consejo: r'Aparta hoy $2,000 de lo que te sobró para tu meta del viaje.',
                  generadoDia: claveDia(DateTime.now()),
                ),
              ),
            ),
          ],
          child: RepaintBoundary(
            key: llave,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.actual,
              home: const AnalisisScreen(),
            ),
          ),
        ),
      );
      await _avanzar(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('2 cargos'), findsOneWidget);
      expect(
        find.text('Gastaste 12% menos que en octubre'),
        plan == PlanNero.gratis ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('Desbloquear con Plus'),
        plan == PlanNero.gratis ? findsOneWidget : findsNothing,
      );
      expect(find.textContaining('al año serían'), findsOneWidget);
      expect(
        find.text('Ver el detalle con Plus'),
        plan == PlanNero.gratis ? findsNWidgets(2) : findsNothing,
      );
      await _capturar(tester, llave, 'analisis_$nombre');
    });
  }

  for (final (nombre, tamano) in [
    ('escritorio', const Size(1600, 1000)),
    ('telefono', const Size(400, 900)),
  ]) {
    testWidgets('Pro de punta a punta: $nombre', (tester) async {
      addTearDown(ConversorMoneda.reiniciar);
      final llave = await _montarInicio(
        tester,
        TemaApp.negro,
        tamano,
        plan: PlanNero.pro,
        cuentas: [
          ..._cuentas,
          const Cuenta(
            id: 'usd',
            nombre: 'Ahorro en dólares',
            tipo: TipoCuenta.debito,
            saldoActual: 500,
            moneda: 'USD',
          ),
        ],
      );
      expect(tester.takeException(), isNull);

      // Multimoneda: la cuenta en dólares suma convertida (500 × 18) al
      // patrimonio y se muestra en su moneda.
      expect(find.text(r'$35,342.42'), findsOneWidget);
      _router.go('/accounts');
      await _avanzar(tester);
      expect(find.text(r'$500.00 USD'), findsWidgets);
      await _capturar(tester, llave, 'pro_cuentas_$nombre');

      // Reportes avanzados con Pro: sin candados.
      _router.go('/reports');
      await _avanzar(tester);
      await tester.scrollUntilVisible(
        find.textContaining('Tu ${DateTime.now().year}'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await _avanzar(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Reportes avanzados'), findsOneWidget);
      expect(find.textContaining('A este ritmo cerrarás'), findsOneWidget);
      expect(find.textContaining('Desbloquear con'), findsNothing);
      await _capturar(tester, llave, 'pro_reportes_$nombre');

      // Exportar: con Pro el PDF está disponible (sin etiqueta "Pro").
      _router.go('/movements');
      await _avanzar(tester);
      await tester.tap(
        tamano.width >= 1000
            ? find.text('Exportar')
            : find.byTooltip('Exportar'),
      );
      await _avanzar(tester);
      expect(find.text('Exportar movimientos'), findsOneWidget);
      await tester.tap(find.text('PDF'));
      await _avanzar(tester);
      expect(find.text('Pro'), findsNothing);
      await _capturar(tester, llave, 'pro_exportar_$nombre');
      await tester.tap(find.text('Cancelar'));
      await _avanzar(tester);

      // Panel "Crear movimiento": botón de la foto del ticket.
      await tester.tap(
        tamano.width >= 1000
            ? find.text('Nuevo movimiento')
            : find.text('Nuevo'),
      );
      await _avanzar(tester);
      expect(find.text('Llenar con foto del ticket'), findsOneWidget);
      await _capturar(tester, llave, 'pro_panel_ticket_$nombre');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Gratis: candados en reportes avanzados y exportar', (
    tester,
  ) async {
    final llave = await _montarInicio(
      tester,
      TemaApp.negro,
      const Size(400, 900),
    );
    _router.go('/reports');
    await _avanzar(tester);
    await tester.scrollUntilVisible(
      find.text('Reportes avanzados'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await _avanzar(tester);
    expect(find.text('Desbloquear con Plus'), findsOneWidget);
    expect(find.text('Desbloquear con Pro'), findsOneWidget);
    await _capturar(tester, llave, 'gratis_reportes_avanzados');

    _router.go('/movements');
    await _avanzar(tester);
    await tester.tap(find.byTooltip('Exportar'));
    await _avanzar(tester);
    expect(find.text('Exporta tus movimientos con Plus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Respaldos (Pro)', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final llave = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membresiaProvider.overrideWithValue(
            const AsyncData(Membresia(plan: PlanNero.pro)),
          ),
          copiasRespaldoProvider.overrideWith(
            (ref) => Stream.value([
              CopiaRespaldo(
                mes: '2026-11',
                creado: DateTime(2026, 11, 1, 5),
                movimientos: 342,
                partes: 1,
              ),
              CopiaRespaldo(
                mes: '2026-10',
                creado: DateTime(2026, 10, 1, 5),
                movimientos: 301,
                partes: 1,
              ),
            ]),
          ),
        ],
        child: RepaintBoundary(
          key: llave,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.actual,
            home: const RespaldosScreen(),
          ),
        ),
      ),
    );
    await _avanzar(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Hacer un respaldo ahora'), findsOneWidget);
    expect(find.text('342 movimientos · CSV'), findsOneWidget);
    expect(find.byTooltip('Descargar'), findsNWidgets(2));
    await _capturar(tester, llave, 'pro_respaldos');
  });

  for (final (nombre, tamano) in [
    ('escritorio', const Size(1600, 1000)),
    ('telefono', const Size(400, 900)),
  ]) {
    testWidgets('Rediseño nov. 2026: $nombre', (tester) async {
      final llave = await _montarInicio(tester, TemaApp.negro, tamano);
      final ancho = tamano.width >= 1000;

      // --- Detalle de cuenta: la tarjeta vuela desde la lista ---
      _router.go('/accounts');
      await _avanzar(tester);
      await tester.tap(find.text('Efectivo').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      await _capturar(tester, llave, 'diseno_detalle_vuelo_$nombre');
      await _avanzar(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(AccountDetailScreen), findsOneWidget);
      expect(find.text('Movimientos de esta cuenta'), findsOneWidget);
      expect(find.text('Detalles de la cuenta'), findsOneWidget);
      expect(find.text('Amazon'), findsNWidgets(2));
      if (ancho) expect(find.text('CONCEPTO'), findsOneWidget);
      await _capturar(tester, llave, 'diseno_detalle_$nombre');

      // Filtro "Ingresos": no hay ingresos en esta cuenta.
      await tester.tap(find.text('Ingresos').last);
      await _avanzar(tester);
      expect(
        find.text('Ningún movimiento coincide con estos filtros.'),
        findsOneWidget,
      );

      // --- Nueva cuenta: ventana con vista previa en vivo ---
      _router.go('/accounts');
      await _avanzar(tester);
      await tester.tap(find.text(ancho ? 'Agregar cuenta' : 'Agregar').first);
      await _avanzar(tester);
      expect(find.text('Organiza tu dinero en un solo lugar.'), findsOneWidget);
      expect(find.text('VISTA PREVIA'), findsOneWidget);
      await tester.tap(find.text('Crédito').last);
      await _avanzar(tester);
      expect(find.text('Límite de crédito'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Nu');
      await _avanzar(tester);
      // Últimos 4 dígitos: incompletos no se aceptan; completos se ven en
      // la vista previa.
      expect(find.text('Últimos 4 dígitos (recomendado)'), findsOneWidget);
      final digitos = find.byType(TextField).at(3);
      await tester.ensureVisible(digitos);
      await tester.enterText(digitos, '48');
      await tester.enterText(find.byType(TextField).at(1), '5000');
      await tester.enterText(find.byType(TextField).at(2), '7000');
      await tester.tap(find.text('Crear cuenta'));
      await _avanzar(tester);
      expect(
        find.text('Escribe los 4 dígitos completos o deja el campo vacío.'),
        findsOneWidget,
      );
      await tester.enterText(digitos, '48219');
      await _avanzar(tester);
      expect(find.text('•••• 4821'), findsOneWidget);
      await tester.ensureVisible(find.text('Nueva cuenta'));
      await _avanzar(tester);
      await _capturar(tester, llave, 'diseno_nueva_cuenta_$nombre');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Cerrar').last);
      await _avanzar(tester);

      // --- Chat con la tarjeta del movimiento ---
      _router.go('/assistant');
      await _avanzar(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Ver movimiento'), findsOneWidget);
      expect(find.text('Registrado'), findsOneWidget);
      expect(find.text('Registrar un gasto'), findsOneWidget);
      await _capturar(tester, llave, 'diseno_chat_$nombre');

      // "Ver movimiento" lleva a la cuenta del movimiento.
      await tester.tap(find.text('Ver movimiento'));
      await _avanzar(tester);
      expect(find.byType(AccountDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (nombre, tamano) in [
    ('escritorio', const Size(1600, 1000)),
    ('telefono', const Size(400, 900)),
  ]) {
    testWidgets('Personalizar asistente: $nombre', (tester) async {
      // Sin motor de voz en las pruebas: ninguna voz instalada.
      const tts = MethodChannel('flutter_tts');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            tts,
            (call) async => call.method == 'getVoices' ? [] : 1,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(tts, null),
      );
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final llave = GlobalKey();
      final perfil = PerfilUsuario.vacio.copyWith(
        nombreAsistente: 'Lucy',
        onboardingCompletado: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            perfilProvider.overrideWith((ref) => Stream.value(perfil)),
          ],
          child: RepaintBoundary(
            key: llave,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.actual,
              home: MediaQuery(
                // esEscritorio mide el ancho.
                data: MediaQueryData(size: tamano),
                child: const PersonalizarAsistenteScreen(),
              ),
            ),
          ),
        ),
      );
      await _avanzar(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('VISTA PREVIA'), findsOneWidget);
      expect(find.text('Apariencia'), findsOneWidget);
      expect(find.text('Voz y dictado'), findsOneWidget);
      expect(
        find.text('Hola, soy Lucy. ¿Qué registramos hoy?'),
        findsOneWidget,
      );
      expect(find.text('Hablar con Lucy'), findsOneWidget);

      // Elegir "Nova" cambia la vista previa al momento.
      await tester.ensureVisible(find.text('Nova'));
      await tester.tap(find.text('Nova'));
      await _avanzar(tester);
      expect(
        find.text('Hola, soy Nova. ¿Qué registramos hoy?'),
        findsOneWidget,
      );
      expect(find.text('Hablar con Nova'), findsOneWidget);
      await tester.ensureVisible(find.text('VISTA PREVIA'));
      await _avanzar(tester);
      await _capturar(tester, llave, 'personalizar_$nombre');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reportes: día y calendario ($nombre)', (tester) async {
      final llave = await _montarInicio(tester, TemaApp.negro, tamano);
      _router.go('/reports');
      await _avanzar(tester);

      // "Día" muestra "Hoy" con barras por hora.
      await tester.tap(find.text('Día'));
      await _avanzar(tester);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Ingresos y gastos por hora'), findsOneWidget);
      await _capturar(tester, llave, 'reportes_dia_$nombre');

      // Tocar la fecha: se estira hasta "Elegir periodo".
      Future<void> abrir() async {
        await tester.tap(find.byIcon(Icons.calendar_today_rounded).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));
      }

      await abrir();
      await _capturar(tester, llave, 'periodo_abriendo_$nombre');
      await _avanzar(tester);
      expect(find.text('Elegir periodo'), findsOneWidget);
      expect(
        find.text('Selecciona el día que quieres consultar.'),
        findsOneWidget,
      );
      expect(find.text('Rango personalizado'), findsOneWidget);
      expect(find.text('Aplicar periodo'), findsOneWidget);

      // Acceso rápido "Esta semana": la semana en curso, 7 días.
      await tester.tap(find.text('Esta semana'));
      await _avanzar(tester);
      expect(find.text('Semana en curso'), findsOneWidget);
      expect(find.textContaining('· 7 días'), findsOneWidget);
      await _capturar(tester, llave, 'periodo_semana_$nombre');
      await tester.tap(find.text('Aplicar periodo'));
      await _avanzar(tester);
      expect(find.text('Elegir periodo'), findsNothing);
      expect(find.text('Ingresos y gastos por día'), findsOneWidget);

      // Rango personalizado: últimos 30 días.
      await abrir();
      await _avanzar(tester);
      await tester.tap(find.text('Rango personalizado'));
      await _avanzar(tester);
      expect(find.text('Desde'), findsOneWidget);
      expect(find.text('Hasta'), findsOneWidget);
      await tester.tap(find.text('Últimos 30 días'));
      await _avanzar(tester);
      expect(find.textContaining('· 30 días'), findsOneWidget);
      await _capturar(tester, llave, 'periodo_rango_$nombre');
      await tester.tap(find.text('Aplicar periodo'));
      await _avanzar(tester);
      expect(find.textContaining('–'), findsWidgets);

      // Mes: cuadrícula de meses; enero del año pasado.
      await tester.tap(find.text('Mes').first);
      await _avanzar(tester);
      await abrir();
      await _avanzar(tester);
      expect(
        find.text('Selecciona el mes que quieres consultar.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Año anterior'));
      await _avanzar(tester);
      await tester.tap(find.text('Enero'));
      await _avanzar(tester);
      await _capturar(tester, llave, 'periodo_mes_$nombre');
      await tester.tap(find.text('Aplicar periodo'));
      await _avanzar(tester);
      expect(find.text('Enero ${DateTime.now().year - 1}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (nombre, tamano, fondo) in [
    ('escritorio', const Size(1600, 1000), FondoApp.jardinZen),
    ('telefono', const Size(400, 900), FondoApp.cristalOrbital),
  ]) {
    testWidgets('Fondos (Plus): $nombre', (tester) async {
      final llave = await _montarInicio(
        tester,
        TemaApp.rojo,
        tamano,
        plan: PlanNero.plus,
        fondo: fondo,
      );
      await tester.runAsync(
        () => precacheImage(
          AssetImage(fondo.imagen),
          tester.element(find.byType(Scaffold).first),
        ),
      );
      await _avanzar(tester);
      expect(tester.takeException(), isNull);
      // Con Plus, el fondo del perfil se aplica (aunque el color sea rojo).
      expect(ControladorTema.instancia.fondo, fondo);
      expect(find.byType(FondoTema), findsOneWidget);
      await _capturar(tester, llave, 'fondo_inicio_$nombre');

      _router.go('/reports');
      await _avanzar(tester);
      expect(tester.takeException(), isNull);
      await _capturar(tester, llave, 'fondo_reportes_$nombre');
    });
  }

  testWidgets('Fondos: en Gratis no se aplican y piden Plus', (tester) async {
    await _montarInicio(
      tester,
      TemaApp.negro,
      const Size(400, 900),
      fondo: FondoApp.horizonteLunar,
    );
    // El perfil tiene fondo guardado, pero el plan es Gratis: no se usa.
    expect(ControladorTema.instancia.fondo, isNull);

    _router.go('/profile');
    await _avanzar(tester);
    await tester.tap(find.text('Apariencia'));
    await _avanzar(tester);
    expect(find.text('Fondos'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(5));
    await tester.ensureVisible(find.text('Jardín zen'));
    await tester.tap(find.text('Jardín zen'));
    await _avanzar(tester);
    expect(find.text('Fondos exclusivos con Plus'), findsOneWidget);
    expect(ControladorTema.instancia.fondo, isNull);
    expect(tester.takeException(), isNull);
  });
}

String _mesActual() {
  final ahora = DateTime.now();
  return '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}';
}
