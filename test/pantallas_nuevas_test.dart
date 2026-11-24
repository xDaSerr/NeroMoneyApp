import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neromoney_app/core/theme/app_theme.dart';
import 'package:neromoney_app/features/accounts/data/cuenta.dart';
import 'package:neromoney_app/features/accounts/providers/cuentas_providers.dart';
import 'package:neromoney_app/features/auth/providers/auth_providers.dart';
import 'package:neromoney_app/features/compartido/compartido_screen.dart';
import 'package:neromoney_app/features/compartido/data/grupo.dart';
import 'package:neromoney_app/features/compartido/providers/compartido_providers.dart';
import 'package:neromoney_app/features/libreta/data/apunte_libreta.dart';
import 'package:neromoney_app/features/libreta/libreta_screen.dart';
import 'package:neromoney_app/features/libreta/providers/libreta_providers.dart';
import 'package:neromoney_app/features/onboarding/data/perfil_usuario.dart';
import 'package:neromoney_app/features/onboarding/providers/perfil_providers.dart';
import 'package:neromoney_app/features/planes/data/membresia.dart';
import 'package:neromoney_app/features/planes/providers/planes_providers.dart';
import 'package:neromoney_app/features/profile/editar_perfil_screen.dart';

/// Libreta, Compartido y Editar perfil se dibujan sin desbordes en teléfono
/// y escritorio, con datos en memoria (sin Firebase).
///   flutter test test/pantallas_nuevas_test.dart --dart-define=CAPTURAS=CARPETA
/// guarda un PNG por pantalla.
const _carpeta = String.fromEnvironment('CAPTURAS');

Future<void> _cargarFuentes() async {
  Future<void> cargar(String familia, List<String> archivos) async {
    final cargador = FontLoader(familia);
    for (final a in archivos) {
      cargador.addFont(
        Future.value(ByteData.sublistView(await File(a).readAsBytes())),
      );
    }
    await cargador.load();
  }

  await cargar('Outfit', [
    'assets/fonts/Outfit-Regular.ttf',
    'assets/fonts/Outfit-SemiBold.ttf',
    'assets/fonts/Outfit-Bold.ttf',
  ]);
  await cargar('JetBrainsMono', ['assets/fonts/JetBrainsMono-Medium.ttf']);
  final raiz = Platform.environment['FLUTTER_ROOT'];
  if (raiz != null) {
    final iconos = File(
      '$raiz/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
    if (iconos.existsSync()) await cargar('MaterialIcons', [iconos.path]);
  }
}

Future<void> _avanzar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _capturar(WidgetTester t, GlobalKey llave, String nombre) async {
  if (_carpeta.isEmpty) return;
  await t.runAsync(() async {
    final limite =
        llave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagen = await limite.toImage();
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    await File('$_carpeta/$nombre.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
}

final _cuentas = [
  const Cuenta(
    id: 'efectivo',
    nombre: 'Efectivo',
    tipo: TipoCuenta.efectivo,
    saldoActual: 8870,
  ),
  const Cuenta(
    id: 'spin',
    nombre: 'Spin Oxxo',
    tipo: TipoCuenta.debito,
    saldoActual: 17472.42,
    ultimos4Digitos: '5643',
  ),
];

List<ApunteLibreta> _apuntes() {
  final hoy = DateTime.now();
  return [
    ApunteLibreta(
      id: '1',
      direccion: DireccionPrestamo.yoPresto,
      persona: 'Carlos Ruiz',
      telefono: '686 123 4567',
      monto: 1500,
      cuentaId: 'efectivo',
      fecha: hoy.subtract(const Duration(days: 12)),
      fechaPromesa: hoy.subtract(const Duration(days: 2)),
      nota: 'Para la colegiatura',
      pagos: [
        PagoLibreta(monto: 500, fecha: hoy.subtract(const Duration(days: 5))),
      ],
    ),
    ApunteLibreta(
      id: '2',
      direccion: DireccionPrestamo.mePrestan,
      persona: 'Mamá',
      telefono: '686 765 4321',
      monto: 800,
      cuentaId: 'spin',
      fecha: hoy.subtract(const Duration(days: 3)),
      fechaPromesa: hoy.add(const Duration(days: 9)),
    ),
    ApunteLibreta(
      id: '3',
      direccion: DireccionPrestamo.yoPresto,
      persona: 'Ana',
      monto: 300,
      fecha: hoy.subtract(const Duration(days: 1)),
      fechaPromesa: hoy.add(const Duration(days: 1)),
    ),
  ];
}

const _grupo = Grupo(
  id: 'g',
  nombre: 'Casa',
  creador: 'yo',
  miembros: ['yo', 'pareja'],
  nombres: {'yo': 'Daniel', 'pareja': 'Sofía'},
  codigo: 'K7MP2Q',
);

List<GastoCompartido> _gastosGrupo() {
  final hoy = DateTime.now();
  GastoCompartido g(String id, double m, String d, String c, String pago) =>
      GastoCompartido(
        id: id,
        monto: m,
        descripcion: d,
        categoria: c,
        pagoUid: pago,
        entre: const ['yo', 'pareja'],
        fecha: hoy.subtract(Duration(days: id.length)),
      );
  return [
    g('a', 1850, 'Despensa', 'Alimentación', 'yo'),
    g('bb', 6500, 'Renta', 'Vivienda', 'pareja'),
    g('ccc', 620, 'Luz', 'Servicios', 'yo'),
  ];
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(_cargarFuentes);

  Future<GlobalKey> montar(
    WidgetTester tester,
    Size tamano,
    Widget pantalla,
  ) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final llave = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('yo'),
          cuentasProvider.overrideWith((ref) => Stream.value(_cuentas)),
          apuntesLibretaProvider.overrideWith(
            (ref) => Stream.value(_apuntes()),
          ),
          grupoIdProvider.overrideWith((ref) => Stream.value('g')),
          grupoProvider.overrideWith((ref) => Stream.value(_grupo)),
          gastosGrupoProvider.overrideWith(
            (ref, id) => Stream.value(_gastosGrupo()),
          ),
          metasGrupoProvider.overrideWith(
            (ref, id) => Stream.value(const [
              MetaCompartida(
                id: 'm',
                nombre: 'Vacaciones en Mazatlán',
                objetivo: 20000,
                aportes: {'yo': 4500, 'pareja': 3800},
              ),
            ]),
          ),
          membresiaProvider.overrideWithValue(
            const AsyncData(Membresia(plan: PlanNero.pro)),
          ),
          perfilProvider.overrideWith(
            (ref) => Stream.value(
              PerfilUsuario.vacio.copyWith(
                apodo: 'Daniel',
                nombreCompleto: 'Luis Daniel Serrano',
                frase: 'Ahorrando para mi primer carro',
                cumpleanos: (mes: 10, dia: 25),
                onboardingCompletado: true,
              ),
            ),
          ),
        ],
        child: RepaintBoundary(
          key: llave,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.actual,
            home: pantalla,
          ),
        ),
      ),
    );
    await _avanzar(tester);
    return llave;
  }

  for (final (nombre, tamano) in [
    ('telefono', const Size(400, 1400)),
    ('escritorio', const Size(1400, 1000)),
  ]) {
    testWidgets('Libreta: $nombre', (tester) async {
      final llave = await montar(tester, tamano, const LibretaScreen());
      expect(tester.takeException(), isNull);
      // 1000 que falta de Carlos + 300 de Ana.
      expect(find.text(r'$1,300.00'), findsOneWidget);
      expect(find.text('Venció hace 2 días'), findsOneWidget);
      expect(find.text('Paga mañana'), findsOneWidget);
      await _capturar(tester, llave, 'libreta_$nombre');

      await tester.tap(find.text('Anotar'));
      await _avanzar(tester);
      expect(find.text('¿De dónde salió el dinero?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capturar(tester, llave, 'libreta_nuevo_$nombre');
    });

    testWidgets('Compartido: $nombre', (tester) async {
      final llave = await montar(tester, tamano, const CompartidoScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Código para invitar: K7MP2Q'), findsOneWidget);
      await _capturar(tester, llave, 'compartido_$nombre');

      await tester.tap(find.text('Cuentas claras'));
      await _avanzar(tester);
      // Renta 6500 de Sofía, 2470 de Daniel: Daniel le debe 2015.
      expect(find.text(r'Daniel le paga $2,015.00 a Sofía'), findsOneWidget);
      await _capturar(tester, llave, 'compartido_balance_$nombre');

      await tester.tap(find.text('Metas'));
      await _avanzar(tester);
      expect(find.text('Vacaciones en Mazatlán'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Editar perfil: $nombre', (tester) async {
      final llave = await montar(tester, tamano, const EditarPerfilScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('25 de octubre'), findsOneWidget);
      await _capturar(tester, llave, 'perfil_$nombre');
    });
  }
}
