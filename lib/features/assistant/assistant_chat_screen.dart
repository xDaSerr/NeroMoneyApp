import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/router/app_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/fecha_es.dart';
import '../../core/widgets/anillo_asistente.dart';
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
import 'widgets/pregunta_nombre_asistente.dart';

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
  // En escritorio no hay píldora abajo: el menú es lateral (ver AppShell).
  if (esEscritorio(context)) return 20;
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
  // La pregunta del nombre se hace una sola vez por pantalla, aunque el
  // build() corra varias veces antes de que se guarde la respuesta.
  bool _preguntandoNombre = false;

  /// Primera vez que el usuario abre a su asistente: este se presenta y le
  /// pregunta cómo llamarlo (ver PreguntaNombreAsistente).
  Future<void> _preguntarNombre(String? avatarBase64) async {
    final nombre = await preguntarNombreAsistente(
      context,
      avatarBase64: avatarBase64,
    );
    final perfil = ref.read(perfilProvider).value;
    if (perfil == null) return;
    try {
      await ref
          .read(perfilRepositoryProvider)
          .guardarPerfil(
            perfil.copyWith(nombreAsistente: nombre, asistenteNombrado: true),
          );
    } catch (_) {
      // Sin conexión, Firestore lo guarda en cuanto vuelva; si de plano
      // falla, se vuelve a preguntar la próxima vez que se abra el chat.
      _preguntandoNombre = false;
    }
  }

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
    // Hasta que el usuario elija el nombre, no se guarda el saludo fijo:
    // así el primer mensaje ya usa el nombre nuevo, no "Lucy".
    final nombrado = perfil?.asistenteNombrado ?? false;
    if (perfil != null && !nombrado && !_preguntandoNombre) {
      _preguntandoNombre = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _preguntarNombre(avatarAsistente);
      });
    }

    return Scaffold(
      extendBody: true,
      // El teclado se reserva en el dock; no reducir el cuerpo dos veces.
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(esEscritorio(context) ? 112 : 76),
        child: _Encabezado(
          nombre: nombreAsistente,
          avatarBase64: avatarAsistente,
          colores:
              perfil?.colorAnilloInicio == null ||
                  perfil?.colorAnilloFin == null
              ? null
              : [
                  Color(perfil!.colorAnilloInicio!),
                  Color(perfil.colorAnilloFin!),
                ],
          onPersonalizar: () => context.push('/personalizar-asistente'),
          onLimpiar: _enviando ? null : () => _confirmarLimpiar(context),
        ),
      ),
      body: Builder(
        builder: (context) => mensajesAsync.when(
          data: (mensajes) {
            if (mensajes.isEmpty) {
              _ultimoMensajeId = null;
              // --- Saludo fijo: se guarda una sola vez al abrir el chat vacío ---
              if (!_saludoEnviado && nombrado) {
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
                esEscritorio(context) ? 40 : 16,
                16,
                esEscritorio(context) ? 40 : 16,
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

                // "Hoy", "Ayer", "12 nov": cuando cambia el día.
                final nuevoDia =
                    i == 0 || !_mismoDia(mensajes[i - 1].fecha, m.fecha);
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: m.autor == AutorMensaje.usuario
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (nuevoDia) _SeparadorDia(fecha: m.fecha),
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
                                      avatar: Icon(
                                        Icons.account_balance_wallet_outlined,
                                        size: 16,
                                        color: AppColors.acento,
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
                    ),
                  ),
                );
              },
            );
          },
          loading: () =>
              Center(child: CircularProgressIndicator(color: AppColors.acento)),
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
            if (!hayBorrador)
              _Atajos(
                activo: !_enviando,
                onRegistrar: () {
                  _inputCtrl.text = 'Gasté ';
                  _inputCtrl.selection = TextSelection.collapsed(
                    offset: _inputCtrl.text.length,
                  );
                },
                onConsultar: () {
                  _inputCtrl.text = '¿Cuánto llevo gastado este mes?';
                  _enviar();
                },
              ),
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

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Avatar con anillo, nombre, "● Conectada" y los botones de la derecha.
class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.nombre,
    required this.avatarBase64,
    required this.colores,
    required this.onPersonalizar,
    required this.onLimpiar,
  });

  final String nombre;
  final String? avatarBase64;
  final List<Color>? colores;
  final VoidCallback onPersonalizar;
  final VoidCallback? onLimpiar;

  @override
  Widget build(BuildContext context) {
    final ancho = esEscritorio(context);
    Widget boton(String texto, IconData icono, VoidCallback? onTap) => ancho
        ? Padding(
            padding: const EdgeInsets.only(left: 12),
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icono, size: 22),
              label: Text(texto),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.glassStrokeHighlight),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: AppTextStyles.bodyLg,
              ),
            ),
          )
        : IconButton(tooltip: texto, onPressed: onTap, icon: Icon(icono));

    return SafeArea(
      bottom: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          ancho ? 40 : 14,
          ancho ? 18 : 8,
          ancho ? 40 : 6,
          0,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.glassStrokeStandard),
          ),
        ),
        child: Row(
          children: [
            AnilloAsistente(
              avatarBase64: avatarBase64,
              colores: colores,
              size: ancho ? 76 : 48,
            ),
            SizedBox(width: ancho ? 20 : 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ancho
                        ? AppTextStyles.display.copyWith(fontSize: 34)
                        : AppTextStyles.headlineMd,
                  ),
                  // Es verdad, no adorno: el backend (Cloud Function +
                  // DeepSeek) está conectado.
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.inflowEmerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Conectada',
                        style: AppTextStyles.bodyLg.copyWith(
                          color: AppColors.inflowEmerald,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            boton('Personalizar', Icons.tune_rounded, onPersonalizar),
            boton('Limpiar chat', Icons.history_rounded, onLimpiar),
          ],
        ),
      ),
    );
  }
}

/// "——  Hoy  ——".
class _SeparadorDia extends StatelessWidget {
  const _SeparadorDia({required this.fecha});

  final DateTime fecha;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final ayer = hoy.subtract(const Duration(days: 1));
    final texto = _mismoDia(fecha, hoy)
        ? 'Hoy'
        : _mismoDia(fecha, ayer)
        ? 'Ayer'
        : '${fecha.day} ${mesesEs[fecha.month - 1]}'
              '${fecha.year == hoy.year ? '' : ' ${fecha.year}'}';
    final linea = Expanded(
      child: Divider(color: AppColors.glassStrokeHighlight, thickness: 1),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Row(
        children: [
          const Spacer(),
          linea,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              texto,
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          linea,
          const Spacer(),
        ],
      ),
    );
  }
}

/// "+ Registrar un gasto" y "Consultar mis gastos".
class _Atajos extends StatelessWidget {
  const _Atajos({
    required this.activo,
    required this.onRegistrar,
    required this.onConsultar,
  });

  final bool activo;
  final VoidCallback onRegistrar;
  final VoidCallback onConsultar;

  @override
  Widget build(BuildContext context) {
    Widget atajo(String texto, IconData icono, VoidCallback onTap) =>
        OutlinedButton.icon(
          onPressed: activo ? onTap : null,
          icon: Icon(icono, color: AppColors.acento, size: 22),
          label: Text(texto),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            backgroundColor: AppColors.surface1.withValues(alpha: 0.6),
            side: BorderSide(color: AppColors.glassStrokeHighlight),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: const StadiumBorder(),
            textStyle: AppTextStyles.bodyLg,
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            atajo('Registrar un gasto', Icons.add_rounded, onRegistrar),
            const SizedBox(width: 14),
            atajo(
              'Consultar mis gastos',
              Icons.account_balance_wallet_outlined,
              onConsultar,
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
    final ancho = esEscritorio(context);
    return SafeArea(
      top: false,
      // La separación de la navegación ya se añade debajo de esta barra.
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              ancho ? 40 : 12,
              8,
              ancho ? 40 : 12,
              12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Cápsula: texto, micrófono y enviar ---
                Container(
                  constraints: BoxConstraints(minHeight: ancho ? 64 : 54),
                  padding: const EdgeInsets.fromLTRB(22, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: escuchando
                          ? AppColors.outflowCrimson
                          : AppColors.glassStrokeHighlight,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          enabled: !enviando,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppTextStyles.bodyLg.copyWith(
                            fontSize: ancho ? 18 : null,
                          ),
                          decoration: InputDecoration(
                            // El tema global define bordes con relleno: hay
                            // que apagar los tres o se ve una píldora dentro
                            // de otra.
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            filled: false,
                            isCollapsed: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            hintText: escuchando
                                ? 'Escuchando...'
                                : 'Escribe a $nombreAsistente…',
                          ),
                          onSubmitted: (_) => onEnviar(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // --- Micrófono: mantener presionado, soltar envía ---
                      Tooltip(
                        message: 'Mantén pulsado para hablar',
                        child: GestureDetector(
                          onTapDown: (_) => onMicPress(),
                          onTapUp: (_) => onMicRelease(),
                          onTapCancel: onMicCancel,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: ancho ? 50 : 42,
                            height: ancho ? 50 : 42,
                            decoration: BoxDecoration(
                              color: escuchando
                                  ? AppColors.outflowCrimson.withValues(
                                      alpha: 0.2,
                                    )
                                  : AppColors.surface3ActiveGlass,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: escuchando
                                    ? AppColors.outflowCrimson
                                    : AppColors.glassStrokeHighlight,
                              ),
                            ),
                            child: Icon(
                              escuchando
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                              color: escuchando
                                  ? AppColors.outflowCrimson
                                  : AppColors.textPrimary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // --- Enviar ---
                      Tooltip(
                        message: 'Enviar',
                        child: GestureDetector(
                          onTap: enviando ? null : onEnviar,
                          child: Container(
                            width: ancho ? 56 : 46,
                            height: ancho ? 56 : 46,
                            decoration: BoxDecoration(
                              color: AppColors.acento,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.acento.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: enviando
                                ? Padding(
                                    padding: const EdgeInsets.all(15),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: AppColors.sobreAcento,
                                    ),
                                  )
                                : Icon(
                                    Icons.send_rounded,
                                    color: AppColors.sobreAcento,
                                    size: 24,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // En teléfono no: ahí el teclado debe quedar pegado al campo.
                if (ancho) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Mantén pulsado el micrófono para hablar',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
