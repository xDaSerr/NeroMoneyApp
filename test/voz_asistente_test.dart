import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:neromoney_app/features/assistant/data/voz_asistente.dart';
import 'package:neromoney_app/features/onboarding/data/perfil_usuario.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  final voces = [
    {'name': 'vozA', 'locale': 'es-MX', 'network_required': '0'},
    {'name': 'vozB', 'locale': 'es-MX', 'network_required': '1'},
    {'name': 'english', 'locale': 'en-US'},
    {'name': 'no instalada', 'locale': 'es-ES', 'features': 'notInstalled'},
  ];
  late List<MethodCall> llamadas;
  setUp(() {
    llamadas = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          llamadas.add(call);
          return call.method == 'getVoices' ? voces : 1;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'solo lista voces españolas instaladas, sin duplicados y con aviso de red',
    () {
      final lista = VozDisponible.desdeMotor([...voces, voces.first]);
      expect(lista.map((v) => v.nombre), ['vozA', 'vozB']);
      expect(lista.last.red, isTrue);
    },
  );
  test(
    'aplica la voz elegida después del idioma y el tono antes de hablar',
    () async {
      final servicio = VozAsistente();
      await servicio.hablar('Hola', nombre: 'vozB', tono: 0.8);
      expect(llamadas.map((c) => c.method), [
        'stop',
        'setLanguage',
        'getVoices',
        'setVoice',
        'setPitch',
        'speak',
      ]);
      expect(llamadas.singleWhere((c) => c.method == 'setVoice').arguments, {
        'name': 'vozB',
        'locale': 'es-MX',
      });
      expect(
        llamadas.singleWhere((c) => c.method == 'setPitch').arguments,
        0.8,
      );
      llamadas.clear();
      await servicio.hablar('Otra muestra');
      expect(llamadas.any((c) => c.method == 'setVoice'), isFalse);
      expect(llamadas[1].method, 'setLanguage');
    },
  );
  test('voz guardada ausente usa español predeterminado', () async {
    await VozAsistente().hablar('Hola', nombre: 'No existe');
    expect(llamadas.any((c) => c.method == 'setVoice'), isFalse);
    expect(llamadas.last.method, 'speak');
  });
  test(
    'cerrar una muestra durante la carga impide que empiece a hablar después',
    () async {
      final cargando = Completer<void>();
      final resolver = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            llamadas.add(call);
            if (call.method == 'getVoices') {
              cargando.complete();
              await resolver.future;
              return voces;
            }
            return 1;
          });
      final servicio = VozAsistente();
      final muestra = servicio.hablar('No debe sonar', nombre: 'vozA');
      await cargando.future;
      final detener = servicio.detener();
      resolver.complete();
      await Future.wait([muestra, detener]);
      expect(llamadas.any((c) => c.method == 'speak'), isFalse);
    },
  );
  test('perfil antiguo conserva envío al soltar; voz y revisión persisten y se pueden restablecer', () async {
    final db = FakeFirebaseFirestore();
    final doc = db.doc('usuarios/prueba');
    await doc.set({'moneda': 'MXN'});
    final antiguo = PerfilUsuario.fromFirestore(await doc.get());
    expect(antiguo.revisarDictado, isFalse);
    final configurado = antiguo.copyWith(
      vozNombre: 'vozB',
      vozIdioma: 'es-MX',
      vozTono: 0.8,
      revisarDictado: true,
    );
    await doc.set(configurado.toFirestore());
    final guardado = PerfilUsuario.fromFirestore(await doc.get());
    expect(guardado.vozNombre, 'vozB');
    expect(guardado.vozTono, 0.8);
    expect(guardado.revisarDictado, isTrue);
    expect(guardado.copyWith(nombreAsistente: 'Nero').vozNombre, 'vozB');
    expect(guardado.copyWith(vozNombre: '').vozNombre, '');
  });
}
