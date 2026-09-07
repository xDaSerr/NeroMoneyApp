import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../accounts/providers/cuentas_providers.dart';
import '../data/controlador_asistente.dart';

/// Respuesta rápida sobre la pestaña actual. La confirmación y los chips
/// vienen del repositorio; la animación por sí sola nunca indica éxito.
class PanelVozAsistente extends ConsumerWidget {
  const PanelVozAsistente({
    super.key,
    required this.controlador,
    required this.nombre,
  });
  final ControladorAsistente controlador;
  final String nombre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuentas = ref.watch(cuentasProvider).value ?? [];
    final respuesta = controlador.respuesta;
    final titulo = switch (controlador.estado) {
      EstadoDictado.preparando => 'Preparando micrófono…',
      EstadoDictado.escuchando => 'Te escucho · suelta para enviar',
      EstadoDictado.finalizando => 'Terminando dictado…',
      EstadoDictado.enviando => 'Un momento…',
      EstadoDictado.sinVoz => 'No te escuché',
      EstadoDictado.error => 'No se pudo completar',
      _ => respuesta?.registrado == true ? 'Registrado' : nombre,
    };
    final texto =
        controlador.error ??
        respuesta?.contenido ??
        (controlador.transcripcion.isEmpty
            ? 'Di el monto, el gasto y la cuenta.'
            : controlador.transcripcion);
    return Material(
      color: AppColors.surface1,
      elevation: 12,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.glassStrokeHighlight),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 10, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    respuesta?.registrado == true
                        ? Icons.check_circle_rounded
                        : Icons.mic_rounded,
                    color: respuesta?.registrado == true
                        ? AppColors.inflowEmerald
                        : AppColors.primaryCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(titulo, style: AppTextStyles.bodyMd),
                    ),
                  ),
                  // --- Cerrar: cancela la captura; un envío iniciado termina ---
                  IconButton(
                    onPressed: controlador.ocultarPanel,
                    tooltip: controlador.capturando
                        ? 'Cancelar dictado'
                        : 'Cerrar respuesta',
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  texto,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (respuesta != null && respuesta.chipsCuentas.isNotEmpty) ...[
                const SizedBox(height: 12),
                // --- Elegir cuenta aquí, sin cambiar al chat ---
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final cuenta in cuentas)
                      if (respuesta.chipsCuentas.contains(cuenta.id))
                        ActionChip(
                          label: Text(cuenta.nombre),
                          onPressed: controlador.ocupado
                              ? null
                              : () => controlador.elegirCuenta(cuenta.id),
                        ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
