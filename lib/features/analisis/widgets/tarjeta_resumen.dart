import 'dart:ui' show ImageFilter;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/fecha_es.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/piezas_movil.dart' show SegmentadoMovil;
import '../../onboarding/providers/perfil_providers.dart';
import '../data/resumen_mensual.dart';
import '../providers/analisis_providers.dart';

/// "Tu resumen de noviembre": lo que Lucy observa del mes (Plus). En
/// Gratis se muestra una vista borrosa con la invitación.
class TarjetaResumenMensual extends ConsumerStatefulWidget {
  const TarjetaResumenMensual({super.key, required this.bloqueado});

  final bool bloqueado;

  @override
  ConsumerState<TarjetaResumenMensual> createState() =>
      _TarjetaResumenMensualState();
}

class _TarjetaResumenMensualState extends ConsumerState<TarjetaResumenMensual> {
  bool _mesPasado = false;
  bool _generando = false;
  String? _error;

  DateTime get _fecha {
    final hoy = DateTime.now();
    return _mesPasado ? DateTime(hoy.year, hoy.month - 1) : hoy;
  }

  Future<void> _generar() async {
    setState(() {
      _generando = true;
      _error = null;
    });
    try {
      await ref.read(resumenRepositoryProvider).generar(claveMes(_fecha));
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'No se pudo generar tu resumen.';
    } catch (_) {
      _error = 'No se pudo generar tu resumen. Intenta de nuevo.';
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asistente =
        ref.watch(perfilProvider).value?.nombreAsistente ?? 'Lucy';
    final mes = mesesEs[_fecha.month - 1];

    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(20),
      color: AppColors.secundario.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.acento),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tu resumen de $mes',
                  style: AppTextStyles.headlineSm,
                ),
              ),
            ],
          ),
          Text(
            '$asistente lee tus números y te cuenta cómo te fue.',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (widget.bloqueado)
            _Bloqueado()
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: SegmentadoMovil<bool>(
                  opciones: const {false: 'Este mes', true: 'Mes pasado'},
                  valor: _mesPasado,
                  onCambiar: (v) => setState(() {
                    _mesPasado = v;
                    _error = null;
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _cuerpo(asistente),
          ],
        ],
      ),
    );
  }

  Widget _cuerpo(String asistente) {
    if (_generando) {
      return Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.acento,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$asistente está leyendo tus números…',
              style: AppTextStyles.bodyMd,
            ),
          ),
        ],
      );
    }
    final resumen = ref.watch(resumenMensualProvider(claveMes(_fecha)));
    return resumen.when(
      loading: () => const SizedBox(height: 40),
      error: (_, _) => _Texto('No se pudo cargar tu resumen.'),
      data: (r) {
        final error = _error == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.outflowCrimson,
                  ),
                ),
              );
        if (r == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.icon(
                onPressed: _generar,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Generar mi resumen'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.acento,
                  foregroundColor: AppColors.sobreAcento,
                  textStyle: AppTextStyles.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
              ?error,
            ],
          );
        }
        if (r.sinDatos) {
          return _Texto('No hay movimientos en este mes para resumir.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(r.titular, style: AppTextStyles.headlineMd),
            const SizedBox(height: 12),
            for (final p in r.puntos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.acento,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p, style: AppTextStyles.bodyLg)),
                  ],
                ),
              ),
            if (r.consejo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.acento.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.acento.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppColors.acento,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r.consejo, style: AppTextStyles.bodyMd),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.mesCerrado
                        ? 'Resumen del mes completo.'
                        : r.actualizadoHoy
                        ? 'Actualizado hoy. Se puede actualizar una vez al día.'
                        : 'Hay movimientos nuevos desde tu último resumen.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textPlaceholder,
                    ),
                  ),
                ),
                if (r.puedeActualizar)
                  TextButton.icon(
                    onPressed: _generar,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Actualizar'),
                  ),
              ],
            ),
            ?error,
          ],
        ).animate().fadeIn(duration: 300.ms);
      },
    );
  }
}

class _Texto extends StatelessWidget {
  const _Texto(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
  );
}

/// Vista previa borrosa (con texto de ejemplo, no datos reales) para Gratis.
class _Bloqueado extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Este mes gastaste menos que el anterior',
                    style: AppTextStyles.headlineMd,
                  ),
                  const SizedBox(height: 10),
                  for (final t in const [
                    'Alimentación fue tu categoría más alta del mes.',
                    'Tus ingresos cubrieron todos tus gastos.',
                    'Ocio bajó bastante respecto al mes pasado.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('•  $t', style: AppTextStyles.bodyLg),
                    ),
                ],
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.acento),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.acento,
                foregroundColor: AppColors.sobreAcento,
                textStyle: AppTextStyles.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              onPressed: () => context.push('/planes'),
              child: const Text('Desbloquear con Plus'),
            ),
          ],
        ),
      ],
    );
  }
}
