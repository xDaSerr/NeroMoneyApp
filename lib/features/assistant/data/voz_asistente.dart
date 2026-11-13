import 'package:flutter_tts/flutter_tts.dart';

class VozDisponible {
  const VozDisponible({
    required this.nombre,
    required this.idioma,
    this.red = false,
  });
  final String nombre;
  final String idioma;
  final bool red;
  String get id => '$idioma|$nombre';
  String get region => switch (idioma.replaceAll('_', '-').toLowerCase()) {
    'es-mx' => 'Español de México',
    'es-es' => 'Español de España',
    'es-us' => 'Español de EE. UU.',
    _ => 'Español ($idioma)',
  };

  static List<VozDisponible> desdeMotor(dynamic datos) {
    final unicas = <String, VozDisponible>{};
    if (datos is! List) return [];
    for (final dato in datos) {
      if (dato is! Map) continue;
      final nombre = dato['name'];
      final idioma = dato['locale'];
      if (nombre is! String ||
          nombre.isEmpty ||
          idioma is! String ||
          !RegExp(r'^es(?:[-_]|$)', caseSensitive: false).hasMatch(idioma)) {
        continue;
      }
      if ((dato['features']?.toString() ?? '').contains('notInstalled')) {
        continue;
      }
      final voz = VozDisponible(
        nombre: nombre,
        idioma: idioma,
        red:
            dato['network_required'] == true ||
            dato['network_required'] == 'true' ||
            dato['network_required'] == '1',
      );
      unicas[voz.id] = voz;
    }
    final lista = unicas.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return lista;
  }
}

/// Una sola salida de audio para muestras y respuestas. Cada cambio de
/// sesión invalida la configuración pendiente para que no hable después
/// de cerrar la pantalla o de iniciar el micrófono.
class VozAsistente {
  VozAsistente({FlutterTts? motor}) : _motor = motor ?? FlutterTts();
  final FlutterTts _motor;
  int _sesion = 0;
  Future<void> _cola = Future.value();

  Future<List<VozDisponible>> voces() async =>
      VozDisponible.desdeMotor(await _motor.getVoices);

  Future<void> detener() {
    ++_sesion;
    final parada = _cola.then((_) async {
      await _motor.stop();
    });
    _cola = parada.catchError((Object _) {});
    return parada;
  }

  Future<void> hablar(
    String texto, {
    String nombre = '',
    String idioma = 'es-MX',
    double tono = 1,
  }) {
    final sesion = ++_sesion;
    bool vigente() => sesion == _sesion;
    final lectura = _cola.then((_) async {
      if (!vigente()) return;
      await _motor.stop();
      if (!vigente()) return;
      // Reiniciar idioma antes de elegir evita conservar la voz anterior
      // al volver a "Predeterminada". Un ID ausente usa el motor local.
      await _motor.setLanguage(idioma);
      if (!vigente()) return;
      if (nombre.isNotEmpty) {
        final disponibles = await voces();
        if (!vigente()) return;
        final elegida = disponibles
            .where((v) => v.nombre == nombre && v.idioma == idioma)
            .firstOrNull;
        if (elegida != null) {
          final resultado = await _motor.setVoice({
            'name': elegida.nombre,
            'locale': elegida.idioma,
          });
          if (resultado == 0) throw StateError('No se pudo activar esta voz.');
        } else {
          await _motor.setLanguage('es-MX');
        }
      }
      if (!vigente()) return;
      await _motor.setPitch(tono.clamp(0.7, 1.3));
      if (!vigente()) return;
      final resultado = await _motor.speak(texto);
      if (resultado == 0) throw StateError('No se pudo reproducir esta voz.');
    });
    _cola = lectura.catchError((Object _) {});
    return lectura;
  }
}
