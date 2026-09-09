import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/asistente_avatar.dart';
import '../../core/widgets/barra_flotante.dart';
import '../accounts/data/cuenta.dart';
import '../accounts/providers/cuentas_providers.dart';
import '../onboarding/providers/perfil_providers.dart';
import 'data/controlador_asistente.dart';
import 'providers/controlador_asistente_provider.dart';
import 'data/mensaje_chat.dart';
import 'providers/asistente_providers.dart';
import 'widgets/burbuja_mensaje.dart';

/// Cuánto dejar entre la barra de texto y la píldora de navegación cuando
/// el teclado está cerrado — el alto real y visible de la píldora
/// (`BarraFlotante.altura - 42`, ver `_FondoBarra.superior` en
/// barra_flotante.dart: la franja transparente de arriba que solo existe
/// para el relieve del avatar, que en el chat nunca aparece porque ahí el
/// dictado del avatar de navegación está desactivado — se usa el
/// micrófono propio del chat, ver CLAUDE.md → "Navegación"). Mientras
/// hay teclado no hace falta: `_construirChat` ya empuja todo el dock
/// hacia arriba con `viewInsets.bottom`.
double _clearanceSobreBarraFlotante(BuildContext context) {
  final gestoInicio = MediaQuery.viewPaddingOf(context).bottom;
  final margenInferior = gestoInicio < 8 ? 8.0 : gestoInicio;
  const alturaPildoraVisible = BarraFlotante.altura - 42;
  return alturaPildoraVisible + margenInferior + 8;
}

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
class AssistantChatScreen extends ConsumerStatefulWidget {
  const AssistantChatScreen({super.key});

  @override
  ConsumerState<AssistantChatScreen> createState() =>
      _AssistantChatScreenState();
}

class _AssistantChatScreenState extends ConsumerState<AssistantChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  ControladorAsistente get _asistente => ref.read(controladorAsistenteProvider);
  bool get _enviando => _asistente.ocupado;
  // Evita disparar el saludo fijo más de una vez por sesión de la pantalla
  // (mensajesAsync puede reconstruir el build() varias veces mientras está
  // vacío). Se reinicia al limpiar la conversación, ver _confirmarLimpiar.
  bool _saludoEnviado = false;
  String? _ultimoMensajeId;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _inputCtrl.text.trim();
    if (texto.isEmpty || _enviando) return;
    _inputCtrl.clear();
    await _asistente.enviarTexto(texto);
    if (mounted) _irAlFinal();
  }

  // --- Micrófono y chips: comparten sesión con el acceso de la barra ---
  void _iniciarEscucha() => _asistente.iniciar();
  void _detenerEscucha() => _asistente.soltar();

  Future<void> _elegirCuenta(String cuentaId) async {
    await _asistente.elegirCuenta(cuentaId);
    if (mounted) _irAlFinal();
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Limpiar',
              style: TextStyle(color: AppColors.outflowCrimson),
            ),
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
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final asistente = ref.watch(controladorAsistenteProvider);
    return ListenableBuilder(
      listenable: asistente,
      builder: (context, _) => _construirChat(context, ref),
    );
  }

  Widget _construirChat(BuildContext context, WidgetRef ref) {
    final mensajesAsync = ref.watch(mensajesChatProvider);
    final hayBorrador = ref.watch(borradorPendienteProvider).value != null;
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final perfil = ref.watch(perfilProvider).value;
    final nombreAsistente = perfil?.nombreAsistente ?? 'Lucy';
    final avatarAsistente = perfil?.avatarAsistenteBase64;
    final cuentasPorId = {for (final c in cuentas) c.id: c};

    return Scaffold(
      extendBody: true,
      // El teclado se reserva en el dock; no reducir el cuerpo dos veces.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Row(
          children: [
            // --- Avatar del asistente en el encabezado (foto elegida por
            // el usuario, o el ícono de la app por defecto) ---
            AsistenteAvatar(avatarBase64: avatarAsistente, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nombreAsistente,
                    style: AppTextStyles.headlineSm,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Esto sí es verdad, no es adorno: el backend (Cloud
                  // Function + DeepSeek) ya está conectado de verdad.
                  Text(
                    'Conectada',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.inflowEmerald,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // --- Botones "Personalizar asistente" y "Limpiar conversación": el
        // primero es el mismo destino que el menú de Perfil (ver
        // ProfileScreen) — solo un atajo, no un lugar distinto — para no
        // tener que salirse del chat a cambiarle la foto o el nombre ---
        actions: [
          IconButton(
            icon: const Icon(Icons.face_retouching_natural_rounded),
            tooltip: 'Personalizar asistente',
            onPressed: () => context.push('/personalizar-asistente'),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Limpiar conversación',
            onPressed: _enviando ? null : () => _confirmarLimpiar(context),
          ),
        ],
      ),
      body: Builder(
        builder: (context) => mensajesAsync.when(
          data: (mensajes) {
            if (mensajes.isEmpty) {
              _ultimoMensajeId = null;
              // --- Saludo fijo: se guarda una sola vez al abrir el chat vacío ---
              if (!_saludoEnviado) {
                _saludoEnviado = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref
                      .read(asistenteRepositoryProvider)
                      .saludarSiEsNuevo(nombreAsistente);
                });
              }
              return _EstadoVacio(
                nombreAsistente: nombreAsistente,
                avatarBase64: avatarAsistente,
              );
            }
            final ultimoId = mensajes.last.id;
            if (_ultimoMensajeId != ultimoId) {
              // Los eventos de voz no son mensajes nuevos. Conservar
              // la posición si el usuario está leyendo el historial.
              final seguirConversacion =
                  _ultimoMensajeId == null ||
                  (_scrollCtrl.hasClients &&
                      _scrollCtrl.position.extentAfter < 120);
              _ultimoMensajeId = ultimoId;
              if (seguirConversacion) _irAlFinal();
            }
            return ListView.builder(
              controller: _scrollCtrl,
              // Scaffold mide el dock real, incluso cuando el texto crece.
              // El viewport llega al fondo; solo el contenido deja margen.
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.paddingOf(context).bottom + 16,
              ),
              itemCount: mensajes.length,
              itemBuilder: (context, i) {
                final m = mensajes[i];
                final esUltimo = i == mensajes.length - 1;
                // Solo el último mensaje puede mostrar chips activos —
                // los de mensajes viejos ya se resolvieron o vencieron.
                final mostrarChips =
                    esUltimo && hayBorrador && m.chipsCuentas.isNotEmpty;

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
                                  avatar: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 16,
                                    color: AppColors.primaryCyan,
                                  ),
                                  label: Text(cuentasPorId[id]!.nombre),
                                  backgroundColor:
                                      AppColors.surface3ActiveGlass,
                                  labelStyle: AppTextStyles.bodySm,
                                  side: BorderSide.none,
                                  onPressed: _enviando
                                      ? null
                                      : () => _elegirCuenta(id),
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
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryCyan),
          ),
          error: (e, _) => Center(
            child: Text(
              'No se pudo cargar la conversación: $e',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.outflowCrimson,
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BarraDeEntrada(
              controller: _inputCtrl,
              enviando: _enviando,
              nombreAsistente: nombreAsistente,
              onEnviar: _enviar,
              escuchando: _asistente.pulsado,
              onMicCancel: _asistente.cancelar,
              onMicPress: _iniciarEscucha,
              onMicRelease: _detenerEscucha,
            ),
            // Para que la píldora flotante de navegación (ver AppShell,
            // extendBody:true) nunca tape la barra de texto — ver
            // _clearanceSobreBarraFlotante arriba para por qué no se usa
            // el alto completo de espacioParaBarraFlotante aquí.
            //
            // AnimatedContainer (con su propia animación de 220ms) en vez
            // de calcular esto cuadro a cuadro contra viewInsets.bottom —
            // esa primera versión sí quitaba el salto brusco, pero
            // recalculaba (y por lo tanto obligaba a Scaffold a re-medir
            // el dock y a la lista de mensajes a recalcular su padding,
            // por el extendBody) en CADA cuadro de la animación nativa del
            // teclado, además de terminar su propio movimiento antes de
            // que el teclado visualmente acabara de cerrarse — esos dos
            // efectos juntos se sentían como "lag"/desincronización. Con
            // un booleano + una sola transición propia, el cálculo solo
            // cambia una vez por apertura/cierre, y la suavidad la pone
            // Flutter, no un valor recalculado a mano en cada frame.
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: MediaQuery.viewInsetsOf(context).bottom > 0
                  ? 0
                  : _clearanceSobreBarraFlotante(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({
    required this.nombreAsistente,
    required this.avatarBase64,
  });
  final String nombreAsistente;
  final String? avatarBase64;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AsistenteAvatar(avatarBase64: avatarBase64, size: 64),
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
    required this.onMicCancel,
    required this.onMicPress,
    required this.onMicRelease,
  });

  final TextEditingController controller;
  final bool enviando;
  final String nombreAsistente;
  final VoidCallback onEnviar;
  final bool escuchando;
  final VoidCallback onMicCancel;
  final VoidCallback onMicPress;
  final VoidCallback onMicRelease;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      // La separación de la navegación ya se añade debajo de esta barra.
      bottom: false,
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
                    hintText: escuchando
                        ? 'Escuchando...'
                        : 'Escribe a $nombreAsistente...',
                  ),
                  onSubmitted: (_) => onEnviar(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // --- Botón de micrófono: mantener presionado para hablar, soltar para enviar ---
            GestureDetector(
              onTapDown: (_) => onMicPress(),
              onTapUp: (_) => onMicRelease(),
              onTapCancel: onMicCancel,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: escuchando
                      ? AppColors.outflowCrimson.withValues(alpha: 0.2)
                      : AppColors.surface3ActiveGlass,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: escuchando
                        ? AppColors.outflowCrimson
                        : AppColors.glassStrokeStandard,
                  ),
                ),
                child: Icon(
                  escuchando ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: escuchando
                      ? AppColors.outflowCrimson
                      : AppColors.textSecondary,
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.canvas,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: AppColors.canvas,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
