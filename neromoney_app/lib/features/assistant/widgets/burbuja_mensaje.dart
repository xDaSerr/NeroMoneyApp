import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/asistente_avatar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../onboarding/providers/perfil_providers.dart';
import '../data/mensaje_chat.dart';

/// Una burbuja del chat — violeta y alineada a la derecha si es del
/// usuario, vidrio esmerilado y alineada a la izquierda (con un pequeño
/// avatar) si es del asistente. Mismo patrón visual que el Stitch de
/// referencia (`11._asistente_ia_chat_con_lucy`); el avatar es la foto que
/// el usuario haya elegido para su asistente, o el ícono de la app si no
/// eligió ninguna (ver AsistenteAvatar / PersonalizarAsistenteScreen).
class BurbujaMensaje extends ConsumerWidget {
  const BurbujaMensaje({super.key, required this.mensaje});

  final MensajeChat mensaje;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esUsuario = mensaje.autor == AutorMensaje.usuario;
    final avatarAsistente = ref.watch(perfilProvider).value?.avatarAsistenteBase64;

    return Row(
      mainAxisAlignment: esUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!esUsuario) ...[
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 2),
            child: AsistenteAvatar(avatarBase64: avatarAsistente, size: 24),
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
