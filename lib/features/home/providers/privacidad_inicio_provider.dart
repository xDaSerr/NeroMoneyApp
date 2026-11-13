import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de privacidad de este dispositivo, conservada entre sesiones.
final privacidadInicioProvider = AsyncNotifierProvider<PrivacidadInicio, bool>(
  PrivacidadInicio.new,
);

class PrivacidadInicio extends AsyncNotifier<bool> {
  static const _clave = 'ocultar_importes_inicio';
  Future<void> _guardado = Future.value();

  @override
  Future<bool> build() async {
    final preferencias = await SharedPreferences.getInstance();
    return preferencias.getBool(_clave) ?? false;
  }

  Future<void> alternar() {
    final ocultar = !(state.value ?? true);
    state = AsyncData(ocultar);
    // Mantener el orden de escritura incluso si se toca el ojo rápidamente.
    // Un fallo de guardado nunca debe volver a revelar los importes en pantalla.
    final guardado = _guardado.then((_) async {
      final preferencias = await SharedPreferences.getInstance();
      if (!await preferencias.setBool(_clave, ocultar)) {
        throw StateError('No se pudo guardar la privacidad de Inicio');
      }
    });
    _guardado = guardado.catchError((Object _) {});
    return guardado;
  }
}
