import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/mensaje_chat.dart';

/// Una burbuja del chat — violeta y alineada a la derecha si es del
/// usuario, vidrio esmerilado y alineada a la izquierda (con un pequeño
/// avatar) si es de Lucy. Mismo patrón visual que el Stitch de referencia
/// (`11._asistente_ia_chat_con_lucy`), sin la foto real de Lucy porque no
/// tenemos ese asset — usamos el mismo ícono que ya representa al
/// asistente en el resto de la app (onboarding, avisos de Inicio).
class BurbujaMensaje extends StatelessWidget {
  const BurbujaMensaje({super.key, required this.mensaje});

  final MensajeChat mensaje;

  @override
  Widget build(BuildContext context) {
    final esUsuario = mensaje.autor == AutorMensaje.usuario;

    return Row(
      mainAxisAlignment: esUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!esUsuario) ...[
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 6, bottom: 2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: AppColors.userBubbleGradient),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 12),
          ),
        ],
        Flexible(
          child: esUsuario
              ? Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.userBubbleGradient),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    mensaje.contenido,
                    style: AppTextStyles.bodyMd.copyWith(color: Colors.white),
                  ),
                )
              : GlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mensaje.contenido, style: AppTextStyles.bodyMd),
                      // --- Marca "✅ Registrado": solo aparece si esta
                      // confirmación vino de verdad de guardar la
                      // transacción en Firestore (ver AsistenteRepository).
                      // Si algún día Lucy "confirma" algo en texto sin
                      // haberlo guardado de verdad, se va a notar porque
                      // esta marca no va a aparecer. ---
                      if (mensaje.registrado) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 13, color: AppColors.inflowEmerald),
                            const SizedBox(width: 4),
                            Text('Registrado',
                                style: AppTextStyles.labelCode
                                    .copyWith(color: AppColors.inflowEmerald)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
