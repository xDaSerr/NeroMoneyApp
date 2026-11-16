import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/moneda/conversor_moneda.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/fecha_es.dart';
import '../../../core/widgets/anillo_asistente.dart';
import '../../accounts/providers/cuentas_providers.dart';
import '../../onboarding/data/perfil_usuario.dart';
import '../../onboarding/providers/perfil_providers.dart';
import '../../transactions/data/categoria.dart';
import '../data/mensaje_chat.dart';

/// Una burbuja del chat (diseño del usuario, nov. 2026): morada a la
/// derecha si es del usuario; vidrio a la izquierda, con el avatar del
/// asistente, si es de él. Si el mensaje confirma un registro trae la
/// tarjeta del movimiento con "Ver movimiento".
class BurbujaMensaje extends ConsumerWidget {
  const BurbujaMensaje({super.key, required this.mensaje});

  final MensajeChat mensaje;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esUsuario = mensaje.autor == AutorMensaje.usuario;
    final perfil = ref.watch(perfilProvider).value;
    final ancho = MediaQuery.sizeOf(context).width >= 700;
    final estiloTexto = AppTextStyles.bodyLg.copyWith(
      fontSize: ancho ? 17 : 15.5,
    );

    if (esUsuario) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ancho ? 560 : 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: AppColors.degradadoBurbuja),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secundario.withValues(alpha: 0.18),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Text(
              mensaje.contenido,
              style: estiloTexto.copyWith(color: Colors.white),
            ),
          ),
        ),
      );
    }

    final movimiento = mensaje.movimiento;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnilloAsistente(
          avatarBase64: perfil?.avatarAsistenteBase64,
          colores: _colores(perfil),
          size: ancho ? 44 : 32,
        ),
        SizedBox(width: ancho ? 14 : 10),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ancho ? 640 : 320),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.surface2Glass,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassStrokeHighlight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mensaje.contenido, style: estiloTexto),
                  // --- Tarjeta del movimiento: solo si de verdad se guardó
                  // (ver AsistenteRepository._intentarRegistrarYConfirmar).
                  if (mensaje.registrado && movimiento != null) ...[
                    const SizedBox(height: 12),
                    _TarjetaMovimiento(movimiento: movimiento, ancho: ancho),
                  ] else if (mensaje.registrado) ...[
                    const SizedBox(height: 8),
                    const _MarcaRegistrado(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Color>? _colores(PerfilUsuario? perfil) {
    final inicio = perfil?.colorAnilloInicio;
    final fin = perfil?.colorAnilloFin;
    if (inicio == null || fin == null) return null;
    return [Color(inicio), Color(fin)];
  }
}

class _MarcaRegistrado extends StatelessWidget {
  const _MarcaRegistrado();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: AppColors.inflowEmerald,
        ),
        const SizedBox(width: 6),
        Text(
          'Registrado',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.inflowEmerald,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TarjetaMovimiento extends ConsumerWidget {
  const _TarjetaMovimiento({required this.movimiento, required this.ancho});

  final Map<String, dynamic> movimiento;
  final bool ancho;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuentaId = movimiento['cuentaId'] as String? ?? '';
    final cuentas = ref.watch(cuentasProvider).value ?? const [];
    final cuenta = cuentas.where((c) => c.id == cuentaId).firstOrNull;
    final categoria = movimiento['categoria'] as String? ?? 'Otro';
    final descripcion = (movimiento['descripcion'] as String? ?? '').trim();
    final titulo = descripcion.isEmpty
        ? categoria
        : '${descripcion[0].toUpperCase()}${descripcion.substring(1)}';
    final esIngreso = movimiento['tipo'] == 'ingreso';
    final monto = (movimiento['monto'] as num?)?.toDouble() ?? 0;
    final fecha = (movimiento['fecha'] as Timestamp?)?.toDate();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassStrokeHighlight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: ancho ? 58 : 46,
                  height: ancho ? 58 : 46,
                  decoration: BoxDecoration(
                    color: AppColors.secundario.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    iconoParaCategoria(categoria),
                    color: Colors.white,
                    size: ancho ? 28 : 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.headlineSm,
                      ),
                      Text(
                        [categoria, ?cuenta?.nombre].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (fecha != null)
                        Text(
                          '${fecha.day} ${mesesEs[fecha.month - 1].substring(0, 3)} ${fecha.year}',
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${esIngreso ? '+' : '−'}'
                      '${ConversorMoneda.formato(monto, cuentaId)}',
                      style: AppTextStyles.headlineSm.copyWith(
                        color: esIngreso
                            ? AppColors.inflowEmerald
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _MarcaRegistrado(),
                  ],
                ),
              ],
            ),
          ),
          if (cuenta != null) ...[
            Divider(height: 1, color: AppColors.glassStrokeStandard),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    context.push('/accounts/detalle', extra: cuentaId),
                iconAlignment: IconAlignment.end,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                icon: Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.acento,
                ),
                label: Text(
                  'Ver movimiento',
                  style: AppTextStyles.bodyLg.copyWith(color: AppColors.acento),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
