import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../accounts/data/cuenta.dart';
import '../accounts/providers/cuentas_providers.dart';
import '../onboarding/providers/perfil_providers.dart';
import '../onboarding/widgets/currency_picker.dart';
import 'data/mensaje_chat.dart';
import 'providers/asistente_providers.dart';
import 'widgets/burbuja_mensaje.dart';

/// Chat con Lucy — sigue el diseño de `11._asistente_ia_chat_con_lucy` del
/// Stitch (burbujas, chips de selección rápida, barra de entrada en
/// cápsula, micrófono) pero solo con lo que ya existe de verdad: no hay
/// foto real de Lucy, y no hay sugerencias de análisis ("¿cuánto he
/// gastado hoy?") como accesos rápidos porque ya se puede simplemente
/// preguntar por texto o voz — se agregan como chips si hace falta más
/// adelante.
///
/// Voz (decisión explícita del usuario): Lucy solo "habla" (texto a voz) en
/// la respuesta a un mensaje que el usuario le dictó por micrófono — si el
/// usuario escribe a mano, la respuesta es silenciosa, como hasta ahora. No
/// hay un interruptor de "modo voz" separado: activar el micrófono para
/// una pregunta ES la decisión de activar la voz para esa respuesta.
/// Reemplaza "$1,234.56" por "1,234.56 pesos" (o la moneda que corresponda)
/// antes de mandarle el texto al lector de voz — sin esto, el "$" se lee
/// como dólares sin importar la moneda real que configuró el usuario.
String _textoParaVoz(String texto, String codigoMoneda) {
  final palabra = monedaHablada(codigoMoneda);
  return texto.replaceAllMapped(
    RegExp(r'\$([\d,]+\.?\d*)'),
    (match) => '${match.group(1)} $palabra',
  );
}

class AssistantChatScreen extends ConsumerStatefulWidget {
  const AssistantChatScreen({super.key});

  @override
  ConsumerState<AssistantChatScreen> createState() => _AssistantChatScreenState();
}

class _AssistantChatScreenState extends ConsumerState<AssistantChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _enviando = false;
  // Evita disparar el saludo fijo más de una vez por sesión de la pantalla
  // (mensajesAsync puede reconstruir el build() varias veces mientras está
  // vacío). Se reinicia al limpiar la conversación, ver _confirmarLimpiar.
  bool _saludoEnviado = false;

  final _voz = stt.SpeechToText();
  final _tts = FlutterTts();
  bool _vozDisponible = false;
  // Marca si el mensaje que se está por mandar vino del micrófono — así
  // sabemos si hay que leer la respuesta de Lucy en voz alta o no.
  bool _ultimoMensajeFueVoz = false;

  @override
  void initState() {
    super.initState();
    _iniciarVoz();
    _tts.setLanguage('es-MX');
  }

  Future<void> _iniciarVoz() async {
    final disponible = await _voz.initialize(onError: _errorDeVoz);
    if (mounted) setState(() => _vozDisponible = disponible);
  }

  void _errorDeVoz(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo escuchar bien: ${error.errorMsg}')),
    );
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _voz.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _inputCtrl.text.trim();
    if (texto.isEmpty || _enviando) return;
    final cuentas = ref.read(cuentasProvider).value ?? const <Cuenta>[];
    final fueVoz = _ultimoMensajeFueVoz;
    _ultimoMensajeFueVoz = false;

    setState(() => _enviando = true);
    _inputCtrl.clear();
    try {
      final repositorio = ref.read(asistenteRepositoryProvider);
      await repositorio.enviarMensaje(texto, cuentas);
      _irAlFinal();
      // Solo se lee en voz alta si el usuario dictó esta pregunta por
      // micrófono — un mensaje escrito a mano siempre responde en silencio.
      final respuesta = repositorio.ultimoMensajeAsistente;
      if (fueVoz && respuesta != null) {
        final moneda = ref.read(perfilProvider).value?.moneda ?? 'MXN';
        await _tts.speak(_textoParaVoz(respuesta, moneda));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // --- Botón de micrófono estilo "mantener presionado para hablar" ---
  // Empieza a escuchar al presionar (onTapDown) y se detiene al soltar
  // (onTapUp/onTapCancel) — como una nota de voz, no un interruptor.
  Future<void> _iniciarEscucha() async {
    if (_voz.isListening) return;
    if (!_vozDisponible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo activar el micrófono — revisa los permisos de la app.'),
        ),
      );
      return;
    }
    _inputCtrl.clear();
    setState(() {});
    await _voz.listen(
      listenOptions: stt.SpeechListenOptions(localeId: 'es_MX'),
      onResult: (resultado) {
        setState(() => _inputCtrl.text = resultado.recognizedWords);
        // `finalResult` también llega si el usuario ya soltó el botón (eso
        // llama a `_voz.stop()`, que fuerza este resultado final) — en ese
        // caso mandamos el mensaje ya transcrito solo, sin tocar "enviar".
        if (resultado.finalResult && resultado.recognizedWords.trim().isNotEmpty) {
          _ultimoMensajeFueVoz = true;
          _enviar();
        }
      },
    );
    setState(() {});
  }

  Future<void> _detenerEscucha() async {
    if (!_voz.isListening) return;
    await _voz.stop();
    setState(() {});
  }

  // --- Se dispara al tocar un chip de cuenta (nivel 4 de resolución de ambigüedad) ---
  Future<void> _elegirCuenta(String cuentaId) async {
    if (_enviando) return;
    final cuentas = ref.read(cuentasProvider).value ?? const <Cuenta>[];
    setState(() => _enviando = true);
    try {
      await ref.read(asistenteRepositoryProvider).completarBorradorConChip(cuentaId, cuentas);
      _irAlFinal();
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // Borrar la conversación es irreversible (aunque no toca dinero real,
  // ver AsistenteRepository.limpiarHistorial) — mejor confirmar antes.
  Future<void> _confirmarLimpiar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('¿Limpiar la conversación?'),
        content: Text(
          'Se borra el historial del chat. Tus cuentas y movimientos reales no se '
          'ven afectados — Lucy sigue pudiendo consultarlos normalmente.',
          style: AppTextStyles.bodyMd,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpiar', style: TextStyle(color: AppColors.outflowCrimson)),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await ref.read(asistenteRepositoryProvider).limpiarHistorial();
      // Para que el saludo fijo vuelva a aparecer en el chat ya vacío.
      _saludoEnviado = false;
    }
  }

  void _irAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final mensajesAsync = ref.watch(mensajesChatProvider);
    final hayBorrador = ref.watch(borradorPendienteProvider).value != null;
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final nombreAsistente = ref.watch(perfilProvider).value?.nombreAsistente ?? 'Lucy';
    final cuentasPorId = {for (final c in cuentas) c.id: c};

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // --- Avatar de Lucy en el encabezado ---
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: AppColors.userBubbleGradient),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(nombreAsistente, style: AppTextStyles.headlineSm, overflow: TextOverflow.ellipsis),
                  // Esto sí es verdad, no es adorno: el backend (Cloud
                  // Function + DeepSeek) ya está conectado de verdad.
                  Text('Conectada',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.inflowEmerald)),
                ],
              ),
            ),
          ],
        ),
        // --- Botón "Limpiar conversación" (como el del Stitch) ---
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Limpiar conversación',
            onPressed: () => _confirmarLimpiar(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: mensajesAsync.when(
              data: (mensajes) {
                if (mensajes.isEmpty) {
                  // --- Saludo fijo: se guarda una sola vez al abrir el chat vacío ---
                  if (!_saludoEnviado) {
                    _saludoEnviado = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.read(asistenteRepositoryProvider).saludarSiEsNuevo(nombreAsistente);
                    });
                  }
                  return _EstadoVacio(nombreAsistente: nombreAsistente);
                }
                _irAlFinal();
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: mensajes.length,
                  itemBuilder: (context, i) {
                    final m = mensajes[i];
                    final esUltimo = i == mensajes.length - 1;
                    // Solo el último mensaje puede mostrar chips activos —
                    // los de mensajes viejos ya se resolvieron o vencieron.
                    final mostrarChips = esUltimo && hayBorrador && m.chipsCuentas.isNotEmpty;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: m.autor == AutorMensaje.usuario
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          BurbujaMensaje(mensaje: m),
                          if (mostrarChips) ...[
                            const SizedBox(height: 8),
                            // --- Chips de selección rápida de cuenta (nunca pregunta abierta) ---
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final id in m.chipsCuentas)
                                  if (cuentasPorId[id] != null)
                                    ActionChip(
                                      avatar: const Icon(Icons.account_balance_wallet_outlined,
                                          size: 16, color: AppColors.primaryCyan),
                                      label: Text(cuentasPorId[id]!.nombre),
                                      backgroundColor: AppColors.surface3ActiveGlass,
                                      labelStyle: AppTextStyles.bodySm,
                                      side: BorderSide.none,
                                      onPressed: _enviando ? null : () => _elegirCuenta(id),
                                    ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan)),
              error: (e, _) => Center(
                child: Text('No se pudo cargar la conversación: $e',
                    style: AppTextStyles.bodyMd.copyWith(color: AppColors.outflowCrimson)),
              ),
            ),
          ),
          _BarraDeEntrada(
            controller: _inputCtrl,
            enviando: _enviando,
            nombreAsistente: nombreAsistente,
            onEnviar: _enviar,
            escuchando: _voz.isListening,
            micDisponible: _vozDisponible,
            onMicPress: _iniciarEscucha,
            onMicRelease: _detenerEscucha,
          ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.nombreAsistente});
  final String nombreAsistente;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.secondaryVioletTint, size: 40),
            const SizedBox(height: 16),
            Text(
              'Cuéntale a $nombreAsistente un gasto o ingreso, ej. "gasté 200 en un café".',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarraDeEntrada extends StatelessWidget {
  const _BarraDeEntrada({
    required this.controller,
    required this.enviando,
    required this.nombreAsistente,
    required this.onEnviar,
    required this.escuchando,
    required this.micDisponible,
    required this.onMicPress,
    required this.onMicRelease,
  });

  final TextEditingController controller;
  final bool enviando;
  final String nombreAsistente;
  final VoidCallback onEnviar;
  final bool escuchando;
  final bool micDisponible;
  final VoidCallback onMicPress;
  final VoidCallback onMicRelease;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.glassStrokeStandard),
                ),
                child: TextField(
                  controller: controller,
                  enabled: !enviando,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.bodyLg,
                  decoration: InputDecoration(
                    // El tema global (app_theme.dart) define su propio
                    // "enabledBorder"/"focusedBorder" con relleno — si solo
                    // se apaga `border`, esos dos igual se dibujan encima
                    // del contenedor de afuera y se ve una píldora dentro
                    // de otra. Hay que apagar los tres explícitamente.
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    hintText: escuchando ? 'Escuchando...' : 'Escribe a $nombreAsistente...',
                  ),
                  onSubmitted: (_) => onEnviar(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // --- Botón de micrófono: mantener presionado para hablar, soltar para enviar ---
            GestureDetector(
              onTapDown: enviando ? null : (_) => onMicPress(),
              onTapUp: (_) => onMicRelease(),
              onTapCancel: onMicRelease,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: escuchando
                      ? AppColors.outflowCrimson.withValues(alpha: 0.2)
                      : AppColors.surface3ActiveGlass,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: escuchando ? AppColors.outflowCrimson : AppColors.glassStrokeStandard,
                  ),
                ),
                child: Icon(
                  escuchando ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: escuchando ? AppColors.outflowCrimson : AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // --- Botón "Enviar" ---
            GestureDetector(
              onTap: enviando ? null : onEnviar,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.ctaGradient),
                  shape: BoxShape.circle,
                ),
                child: enviando
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.canvas),
                      )
                    : const Icon(Icons.send_rounded, color: AppColors.canvas, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
