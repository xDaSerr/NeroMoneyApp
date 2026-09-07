import 'dart:async';

import 'package:flutter/foundation.dart';

import 'mensaje_chat.dart';

enum EstadoDictado {
  inactivo,
  preparando,
  escuchando,
  finalizando,
  enviando,
  respuesta,
  sinVoz,
  error,
}

class FalloDictado {
  const FalloDictado(this.mensaje, {this.sinVoz = false});
  final String mensaje;
  final bool sinVoz;
}

/// Un solo motor para el chat y la barra: SpeechToText es un singleton.
/// La interfaz permite probar permisos tardíos y resultados duplicados.
abstract class MotorDictado {
  Future<bool> preparar();
  Future<void> escuchar({
    required void Function(String, bool) resultado,
    required void Function(double) nivel,
    required void Function(FalloDictado) error,
  });
  Future<void> detener();
  Future<void> cancelar();
}

class ControladorAsistente extends ChangeNotifier {
  ControladorAsistente({
    required this.motor,
    required this.enviar,
    required this.completar,
    required this.hablar,
    required this.callar,
    this.esperaFinal = const Duration(milliseconds: 1400),
    this.duracionAvisoSinVoz = const Duration(seconds: 3),
  });

  final MotorDictado motor;
  final Future<MensajeChat?> Function(String, bool) enviar;
  final Future<MensajeChat?> Function(String, bool) completar;
  final Future<void> Function(String) hablar;
  final Future<void> Function() callar;
  final Duration esperaFinal;
  final Duration duracionAvisoSinVoz;
  Timer? _temporizadorAviso;

  EstadoDictado estado = EstadoDictado.inactivo;
  String transcripcion = '';
  String? error;
  MensajeChat? respuesta;
  double nivel = 0;
  bool pulsado = false;
  bool mostrarPanel = false;
  bool _respuestaPorVoz = false;
  bool _cerrado = false;
  int _sesion = 0;
  Completer<void>? _resultadoFinal;
  // Una nueva pulsación espera la cancelación nativa anterior para que
  // un resultado tardío no llegue a la siguiente captura.
  Future<void> _limpieza = Future.value();
  Future<void> _arranque = Future.value();
  Future<void> _lectura = Future.value();

  bool get enviando => estado == EstadoDictado.enviando;
  bool get capturando =>
      estado == EstadoDictado.preparando ||
      estado == EstadoDictado.escuchando ||
      estado == EstadoDictado.finalizando;
  bool get ocupado => capturando || enviando;
  bool _vigente(int sesion) => !_cerrado && sesion == _sesion;

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  Future<void> iniciar() async {
    if (ocupado || _cerrado) return;
    _temporizadorAviso?.cancel();
    final arranqueAnterior = _arranque;
    final arranqueActual = Completer<void>();
    _arranque = arranqueActual.future;
    final sesion = ++_sesion;
    pulsado = true;
    mostrarPanel = true;
    transcripcion = '';
    respuesta = null;
    error = null;
    nivel = 0;
    _resultadoFinal = Completer<void>();
    estado = EstadoDictado.preparando;
    _avisar();
    try {
      await arranqueAnterior;
      await _limpieza;
      await _lectura;
      if (!_vigente(sesion) || !pulsado) return;
      await callar();
      if (!_vigente(sesion) || !pulsado) return;
      final disponible = await motor.preparar();
      if (!_vigente(sesion) || !pulsado) return;
      if (!disponible) {
        _fallar('Activa el permiso de micrófono en los ajustes de NeroMoney.');
        return;
      }
      estado = EstadoDictado.escuchando;
      _avisar();
      await motor.escuchar(
        resultado: (texto, finalizado) {
          if (!_vigente(sesion) || !capturando) return;
          transcripcion = texto;
          if (finalizado && !_resultadoFinal!.isCompleted) {
            _resultadoFinal!.complete();
          }
          // Aunque Android termine por silencio, solo enviamos al soltar.
          _avisar();
        },
        nivel: (valor) {
          if (!_vigente(sesion) || !pulsado) return;
          nivel = valor.clamp(0.0, 1.0);
          _avisar();
        },
        error: (fallo) {
          if (_vigente(sesion) && capturando) {
            _fallar(fallo.mensaje, sinVoz: fallo.sinVoz);
          }
        },
      );
      if (!_vigente(sesion)) await motor.cancelar();
    } catch (_) {
      if (_vigente(sesion)) {
        _fallar('No se pudo activar el micrófono. Inténtalo de nuevo.');
      }
    } finally {
      arranqueActual.complete();
    }
  }

  Future<void> soltar() async {
    if (!pulsado || _cerrado) return;
    pulsado = false;
    nivel = 0;
    // Soltar durante el permiso/inicio nunca deja el micrófono abierto.
    if (estado == EstadoDictado.preparando) {
      cancelar();
      return;
    }
    final sesion = _sesion;
    estado = EstadoDictado.finalizando;
    _avisar();
    try {
      await motor.detener();
      await _resultadoFinal!.future.timeout(esperaFinal, onTimeout: () {});
      if (!_vigente(sesion)) return;
      final texto = transcripcion.trim();
      if (texto.isEmpty) {
        _fallar('Mantén pulsado para intentarlo de nuevo.', sinVoz: true);
        return;
      }
      await _procesar(() => enviar(texto, true), voz: true, panel: true);
    } catch (_) {
      if (_vigente(sesion)) {
        _fallar('No se pudo terminar el dictado. Inténtalo de nuevo.');
      }
    }
  }

  Future<void> enviarTexto(String texto) async {
    if (ocupado || texto.trim().isEmpty || _cerrado) return;
    await _procesar(
      () => enviar(texto.trim(), false),
      voz: false,
      panel: false,
    );
  }

  Future<void> elegirCuenta(String id) async {
    if (ocupado || _cerrado) return;
    final voz = _respuestaPorVoz;
    await _procesar(() => completar(id, voz), voz: voz, panel: mostrarPanel);
  }

  Future<void> _procesar(
    Future<MensajeChat?> Function() accion, {
    required bool voz,
    required bool panel,
  }) async {
    _temporizadorAviso?.cancel();
    final sesion = ++_sesion;
    estado = EstadoDictado.enviando;
    mostrarPanel = panel;
    respuesta = null;
    error = null;
    _respuestaPorVoz = voz;
    _avisar();
    try {
      final mensaje = await accion();
      if (!_vigente(sesion)) return;
      respuesta = mensaje;
      estado = EstadoDictado.respuesta;
      if (mensaje == null) {
        _fallar('La solicitud ya no está pendiente. Revisa la conversación.');
        return;
      }
      _avisar();
      // Un fallo de audio no convierte una operación guardada en un error
      // de registro ni invita a repetir un gasto que ya existe.
      if (voz) {
        _lectura = hablar(mensaje.contenido).catchError((Object _) {});
      }
    } catch (_) {
      if (_vigente(sesion)) {
        _fallar(
          'No pude confirmar el resultado. Revisa tus movimientos antes de repetirlo.',
        );
      }
    }
  }

  void _fallar(String mensaje, {bool sinVoz = false}) {
    _temporizadorAviso?.cancel();
    final sesion = ++_sesion;
    pulsado = false;
    nivel = 0;
    estado = sinVoz ? EstadoDictado.sinVoz : EstadoDictado.error;
    error = mensaje;
    mostrarPanel = true;
    _limpieza = motor.cancelar().catchError((Object _) {});
    // Solo el silencio es un aviso pasajero. No ocultar permisos ni
    // resultados inciertos de operaciones que pudieron guardar dinero.
    if (sinVoz) {
      _temporizadorAviso = Timer(duracionAvisoSinVoz, () {
        if (_vigente(sesion) && estado == EstadoDictado.sinVoz) {
          descartarAviso();
        }
      });
    }
    _avisar();
  }

  /// Al volver a tocar el avatar, quitar el aviso sin esperar su cierre
  /// ni cancelar otra vez el motor: la limpieza anterior ya está en curso.
  void descartarAviso() {
    if (estado != EstadoDictado.sinVoz && estado != EstadoDictado.error) return;
    _temporizadorAviso?.cancel();
    estado = EstadoDictado.inactivo;
    error = null;
    mostrarPanel = false;
    _avisar();
  }

  void cancelar() {
    if (enviando) return; // El registro ya enviado debe poder terminar.
    _temporizadorAviso?.cancel();
    ++_sesion;
    pulsado = false;
    nivel = 0;
    estado = EstadoDictado.inactivo;
    mostrarPanel = false;
    _limpieza = motor.cancelar().catchError((Object _) {});
    unawaited(callar().catchError((Object _) {}));
    _avisar();
  }

  void ocultarPanel() {
    _temporizadorAviso?.cancel();
    if (capturando) {
      cancelar();
    } else {
      mostrarPanel = false;
      unawaited(callar().catchError((Object _) {}));
      _avisar();
    }
  }

  @override
  void dispose() {
    _temporizadorAviso?.cancel();
    _cerrado = true;
    ++_sesion;
    unawaited(motor.cancelar().catchError((Object _) {}));
    unawaited(callar().catchError((Object _) {}));
    super.dispose();
  }
}
