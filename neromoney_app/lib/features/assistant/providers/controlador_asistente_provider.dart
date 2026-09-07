import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../accounts/providers/cuentas_providers.dart';
import '../../onboarding/providers/perfil_providers.dart';
import '../../onboarding/widgets/currency_picker.dart';
import '../../transactions/data/transaccion.dart';
import '../data/controlador_asistente.dart';
import 'asistente_providers.dart';
import 'voz_asistente_provider.dart';

// Vive durante la sesión y se destruye al cambiar el repositorio/usuario.
// Chat y navegación comparten tanto micrófono como exclusión de envíos.
final controladorAsistenteProvider = Provider.autoDispose<ControladorAsistente>(
  (ref) {
    final repositorio = ref.watch(asistenteRepositoryProvider);
    final voz = ref.watch(vozAsistenteProvider);
    final controlador = ControladorAsistente(
      motor: _MotorNativo(),
      revisarAntesDeEnviar: () =>
          ref.read(perfilProvider).value?.revisarDictado ?? false,
      enviar: (texto, voz) async {
        final cuentas = await ref.read(cuentasProvider.future);
        await repositorio.enviarMensaje(
          texto,
          cuentas,
          origen: voz ? OrigenTransaccion.iaVoz : OrigenTransaccion.iaTexto,
        );
        return repositorio.ultimaRespuesta;
      },
      completar: (id, voz) async {
        final cuentas = await ref.read(cuentasProvider.future);
        await repositorio.completarBorradorConChip(
          id,
          cuentas,
          origen: voz ? OrigenTransaccion.iaVoz : OrigenTransaccion.iaTexto,
        );
        return repositorio.ultimaRespuesta;
      },
      hablar: (texto) async {
        final perfil = ref.read(perfilProvider).value;
        final moneda = perfil?.moneda ?? 'MXN';
        final hablado = texto.replaceAllMapped(
          RegExp(r'\$([\d,]+\.?\d*)'),
          (m) => '${m.group(1)} ${monedaHablada(moneda)}',
        );
        await voz.hablar(
          hablado,
          nombre: perfil?.vozNombre ?? '',
          idioma: perfil?.vozIdioma ?? 'es-MX',
          tono: perfil?.vozTono ?? 1,
        );
      },
      callar: () async {
        await voz.detener();
      },
    );
    ref.onDispose(controlador.dispose);
    return controlador;
  },
);

class _MotorNativo implements MotorDictado {
  final _voz = stt.SpeechToText();
  void Function(FalloDictado)? _error;
  String? _idioma;

  @override
  Future<bool> preparar() async {
    final disponible = await _voz.initialize(
      finalTimeout: const Duration(milliseconds: 1000),
    );
    if (disponible && _idioma == null) {
      final idiomas = await _voz.locales();
      final espanol = idiomas
          .where((l) => l.localeId.toLowerCase().startsWith('es'))
          .toList();
      _idioma =
          espanol
              .where(
                (l) => l.localeId.replaceAll('_', '-').toLowerCase() == 'es-mx',
              )
              .firstOrNull
              ?.localeId ??
          espanol.firstOrNull?.localeId ??
          'es-MX';
    }
    // initialize solo configura callbacks una vez en este singleton;
    // sustituir el listener permite volver a entrar tras cerrar sesión.
    _voz.errorListener = (e) {
      final sinVoz =
          e.errorMsg == 'error_speech_timeout' ||
          e.errorMsg == 'error_no_match';
      _error?.call(
        FalloDictado(
          sinVoz
              ? 'Mantén pulsado para intentarlo de nuevo.'
              : e.errorMsg.contains('permission')
              ? 'Activa el permiso de micrófono en los ajustes de NeroMoney.'
              : 'No se pudo escuchar bien. Mantén pulsado y vuelve a intentarlo.',
          sinVoz: sinVoz,
        ),
      );
    };
    return disponible;
  }

  @override
  Future<void> escuchar({
    required void Function(String, bool, [double?]) resultado,
    required void Function(double) nivel,
    required void Function(FalloDictado) error,
  }) async {
    _error = error;
    await _voz.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: _idioma,
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 5),
        // El controlador cancela y espera la limpieza antes de reintentar.
        // Una segunda cancelación automática del plugin puede alcanzar
        // la siguiente escucha si el usuario vuelve a pulsar enseguida.
        cancelOnError: false,
        partialResults: true,
      ),
      onResult: (r) => resultado(
        r.recognizedWords,
        r.finalResult,
        r.hasConfidenceRating ? r.confidence : null,
      ),
      onSoundLevelChange: (n) => nivel((n / 10).clamp(0.0, 1.0)),
    );
  }

  @override
  Future<void> detener() => _voz.stop();

  @override
  Future<void> cancelar() async {
    _error = null;
    await _voz.cancel();
  }
}
