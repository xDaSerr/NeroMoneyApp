import 'dart:convert';
import 'dart:developer' as developer;

/// Tiempos locales por etapa, sin texto, importes ni identificadores del usuario.
/// Las etapas paralelas pueden solaparse: no sumar sus tiempos como un total.
class MedicionAsistente {
  final _total = Stopwatch()..start();
  final _etapas = <String, int>{};
  bool _fallo = false;

  Future<T> medir<T>(String etapa, Future<T> Function() accion) async {
    final reloj = Stopwatch()..start();
    try {
      return await accion();
    } catch (_) {
      _fallo = true;
      rethrow;
    } finally {
      _etapas[etapa] = reloj.elapsedMilliseconds;
    }
  }

  Map<String, Object> finalizar() {
    _total.stop();
    final datos = Map<String, Object>.unmodifiable({
      ..._etapas,
      'total_ms': _total.elapsedMilliseconds,
      'fallo': _fallo,
    });
    developer.log(jsonEncode(datos), name: 'NeroMoney.LatenciaAsistente');
    return datos;
  }
}
