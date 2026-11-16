import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/core/theme/controlador_tema.dart';
import 'package:neromoney_app/core/theme/tema_app.dart';
import 'package:neromoney_app/features/onboarding/data/perfil_usuario.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cada fondo tiene su imagen, su miniatura y una paleta oscura', () {
    for (final fondo in FondoApp.values) {
      expect(File(fondo.imagen).existsSync(), isTrue, reason: fondo.imagen);
      expect(
        File(fondo.miniatura).existsSync(),
        isTrue,
        reason: fondo.miniatura,
      );
      // Ligeras para la web.
      expect(File(fondo.imagen).lengthSync(), lessThan(400 * 1024));
      final paleta = PaletaTema.deFondo(fondo);
      expect(paleta.fondo, fondo);
      expect(paleta.esClaro, isFalse);
    }
    // Los 8 colores de siempre no traen fondo.
    for (final tema in TemaApp.values) {
      expect(PaletaTema.de(tema).fondo, isNull);
    }
  });

  test('el perfil guarda el fondo y se puede quitar', () {
    final con = PerfilUsuario.vacio.copyWith(fondo: FondoApp.horizonteLunar);
    expect(con.toFirestore()['fondo'], 'horizonteLunar');
    expect(con.copyWith(apodo: 'x').fondo, FondoApp.horizonteLunar);
    final sin = con.copyWith(fondo: null);
    expect(sin.fondo, isNull);
    // Se guarda null explícito para que quitarlo sí lo borre.
    expect(sin.toFirestore().containsKey('fondo'), isTrue);
    expect(FondoApp.desdeTexto('no-existe'), isNull);
    expect(FondoApp.desdeTexto('jardinZen'), FondoApp.jardinZen);
  });

  test(
    'ControladorTema: el fondo manda sobre el color y se recuerda',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = ControladorTema.instancia;
      c.cambiar(TemaApp.rojo);
      c.cambiarFondo(FondoApp.arquitecturaLuz);
      expect(c.paleta.fondo, FondoApp.arquitecturaLuz);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fondo_app'), 'arquitecturaLuz');

      c.cambiarFondo(null);
      expect(c.paleta, PaletaTema.de(TemaApp.rojo));
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('fondo_app'), isNull);
      c.cambiar(TemaApp.negro);
    },
  );
}
