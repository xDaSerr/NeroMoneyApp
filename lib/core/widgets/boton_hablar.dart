import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'anillo_asistente.dart';

/// Botón flotante "Hablar con {asistente}" del diseño de escritorio (ver
/// AppShell): hace lo mismo que el avatar de la barra del teléfono — un clic
/// abre el chat y mantenerlo presionado dicta (soltar envía).
class BotonHablar extends StatefulWidget {
  const BotonHablar({
    super.key,
    required this.nombreAsistente,
    required this.avatarBase64,
    required this.coloresAnillo,
    required this.escuchando,
    required this.enviando,
    required this.onAbrirChat,
    required this.onPrepararGesto,
    required this.onMantener,
    required this.onSoltar,
    required this.onCancelar,
  });

  /// null = todavía no lo nombra (se muestra "tu asistente").
  final String? nombreAsistente;
  final String? avatarBase64;
  final List<Color>? coloresAnillo;
  final bool escuchando;
  final bool enviando;
  final VoidCallback onAbrirChat;
  final VoidCallback onPrepararGesto;
  final VoidCallback onMantener;
  final VoidCallback onSoltar;
  final VoidCallback onCancelar;

  @override
  State<BotonHablar> createState() => _BotonHablarState();
}

class _BotonHablarState extends State<BotonHablar> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final nombre = widget.nombreAsistente ?? 'tu asistente';
    final titulo = widget.escuchando
        ? 'Te escucho…'
        : widget.enviando
        ? 'Pensando…'
        : 'Hablar con $nombre';
    final subtitulo = widget.escuchando
        ? 'Suelta para enviar'
        : 'Mantén pulsado para hablar';
    final activo = widget.escuchando || _encima;

    return Semantics(
      button: true,
      label: 'Hablar con $nombre. Mantén pulsado para dictar.',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() => _encima = false),
        child: GestureDetector(
          onTapDown: (_) => widget.onPrepararGesto(),
          onTap: widget.onAbrirChat,
          onLongPressStart: (_) => widget.onMantener(),
          onLongPressEnd: (_) => widget.onSoltar(),
          onLongPressCancel: widget.onCancelar,
          child: AnimatedScale(
            scale: widget.escuchando ? 1.04 : (_encima ? 1.02 : 1),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.fromLTRB(8, 8, 22, 8),
              decoration: BoxDecoration(
                color: AppColors.surface1.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: activo
                      ? AppColors.acento.withValues(alpha: 0.8)
                      : AppColors.secundario.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (activo ? AppColors.acento : AppColors.secundario)
                        .withValues(alpha: activo ? 0.35 : 0.2),
                    blurRadius: activo ? 30 : 20,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnilloAsistente(
                    avatarBase64: widget.avatarBase64,
                    colores: widget.coloresAnillo,
                    size: 52,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: AppTextStyles.headlineSm),
                      Text(subtitulo, style: AppTextStyles.bodySm),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Icon(
                    widget.escuchando
                        ? Icons.graphic_eq_rounded
                        : Icons.mic_none_rounded,
                    color: AppColors.acento,
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
