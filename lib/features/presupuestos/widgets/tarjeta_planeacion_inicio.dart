import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../transactions/data/categoria.dart';
import '../data/planeacion.dart';
import '../presupuestos_screen.dart';
import '../providers/planeacion_providers.dart';

/// Resumen en Inicio: aviso si un presupuesto va por el 80% o más, los tres
/// más apretados y la primera meta sin cumplir. Sin nada creado, invita a
/// empezar. Lo usan Inicio de teléfono y de escritorio.
class TarjetaPlaneacionInicio extends ConsumerWidget {
  const TarjetaPlaneacionInicio({
    super.key,
    this.padding = const EdgeInsets.all(18),
    this.radio = 22,
  });

  final EdgeInsetsGeometry padding;
  final double radio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estados = ref.watch(estadosPresupuestoProvider).value;
    final metas = ref.watch(metasProvider).value;
    // Mientras carga no se muestra nada (evita un parpadeo de "Empieza").
    if (estados == null || metas == null) return const SizedBox.shrink();

    void abrir() => context.push('/presupuestos');

    if (estados.isEmpty && metas.isEmpty) {
      return _Contenedor(
        padding: padding,
        radio: radio,
        onTap: abrir,
        child: Row(
          children: [
            Icon(Icons.savings_outlined, color: AppColors.acento, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Presupuestos y metas', style: AppTextStyles.headlineSm),
                  Text(
                    'Ponle tope a tus gastos y ahorra para lo que quieres.',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.acento),
          ],
        ),
      );
    }

    final alertas = estados
        .where((e) => e.nivel != NivelPresupuesto.bien)
        .toList();
    final meta = metas.where((m) => !m.completada).firstOrNull;

    return _Contenedor(
      padding: padding,
      radio: radio,
      onTap: abrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Presupuestos y metas',
                  style: AppTextStyles.headlineSm,
                ),
              ),
              Text(
                'Ver todo',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.acento),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.acento,
              ),
            ],
          ),
          // --- Aviso del presupuesto más apretado ---
          if (alertas.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Alerta(estado: alertas.first, otras: alertas.length - 1),
          ],
          for (final e in estados.take(3)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  iconoParaCategoria(e.presupuesto.categoria),
                  size: 18,
                  color: colorNivel(e.nivel),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.presupuesto.categoria,
                    style: AppTextStyles.bodyMd,
                  ),
                ),
                Text(
                  '${(e.proporcion * 100).round()}%',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: colorNivel(e.nivel),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            BarraProgreso(
              valor: e.proporcion,
              color: colorNivel(e.nivel),
              alto: 7,
            ),
          ],
          if (meta != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.savings_outlined, size: 18, color: AppColors.acento),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meta.nombre,
                    style: AppTextStyles.bodyMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(meta.progreso * 100).round()}%',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.acento,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            BarraProgreso(
              valor: meta.progreso,
              color: AppColors.acento,
              alto: 7,
            ),
          ],
        ],
      ),
    );
  }
}

class _Alerta extends StatelessWidget {
  const _Alerta({required this.estado, required this.otras});

  final EstadoPresupuesto estado;
  final int otras;

  @override
  Widget build(BuildContext context) {
    final color = colorNivel(estado.nivel);
    final categoria = estado.presupuesto.categoria;
    final texto = estado.nivel == NivelPresupuesto.excedido
        ? 'Te pasaste del presupuesto de $categoria.'
        : 'Llevas ${(estado.proporcion * 100).round()}% del presupuesto '
              'de $categoria.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              otras > 0 ? '$texto Y $otras más cerca del límite.' : texto,
              style: AppTextStyles.bodyMd.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Contenedor extends StatelessWidget {
  const _Contenedor({
    required this.child,
    required this.padding,
    required this.radio,
    required this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(borderRadius: radio, padding: padding, child: child),
      ),
    );
  }
}
