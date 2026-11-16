import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/fecha_es.dart';
import '../../core/utils/formato_monto.dart';
import '../../core/widgets/glass_card.dart';
import '../planes/data/membresia.dart';
import '../planes/providers/planes_providers.dart';
import '../transactions/data/categoria.dart';
import 'data/deteccion.dart';
import 'providers/analisis_providers.dart';
import 'widgets/tarjeta_resumen.dart';

/// Análisis inteligente (Plus): cargos fijos/suscripciones y gastos
/// hormiga. En Gratis se ve cuántos encontramos, pero el detalle va
/// borroso con la invitación a Plus.
class AnalisisScreen extends ConsumerWidget {
  const AnalisisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(membresiaProvider).value?.plan ?? PlanNero.gratis;
    final deteccion = ref.watch(deteccionProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Atrás',
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Análisis inteligente',
                    style: AppTextStyles.display.copyWith(fontSize: 34),
                  ),
                  Text(
                    'Cómo te fue y lo que se repite en tus gastos.',
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  // --- Resumen mensual escrito por la asistente ---
                  TarjetaResumenMensual(bloqueado: plan == PlanNero.gratis),
                  const SizedBox(height: 22),
                  deteccion.when(
                    data: (d) => _Contenido(
                      deteccion: d,
                      bloqueado: plan == PlanNero.gratis,
                    ),
                    loading: () => Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.acento,
                        ),
                      ),
                    ),
                    error: (e, _) => Text(
                      'No se pudieron analizar tus movimientos.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.outflowCrimson,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Lo calculamos con tus movimientos de los últimos '
                    '${Deteccion.mesesHistoria} meses. Para que funcione '
                    'mejor, ponle descripción a tus gastos (por ejemplo, '
                    '"Netflix" o "Café").',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textPlaceholder,
                    ),
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

class _Contenido extends StatelessWidget {
  const _Contenido({required this.deteccion, required this.bloqueado});

  final Deteccion deteccion;
  final bool bloqueado;

  @override
  Widget build(BuildContext context) {
    final d = deteccion;
    final recurrentes = _Seccion(
      icono: Icons.event_repeat_rounded,
      titulo: 'Suscripciones y cargos fijos',
      resumen: d.recurrentes.isEmpty
          ? 'No encontramos cargos que se repitan cada mes.'
          : '${d.recurrentes.length} '
                '${d.recurrentes.length == 1 ? 'cargo' : 'cargos'} · '
                '${formatoMonto(d.totalRecurrenteMensual)} al mes · '
                '${formatoMonto(d.totalRecurrenteMensual * 12)} al año',
      bloqueado: bloqueado && d.recurrentes.isNotEmpty,
      filas: [
        for (final c in d.recurrentes)
          _Fila(
            icono: iconoParaCategoria(c.categoria),
            titulo: c.nombre,
            detalle:
                'Cada mes · próximo cobro ~${c.proximaFecha.day} '
                '${mesesEs[c.proximaFecha.month - 1].substring(0, 3)}',
            monto: formatoMonto(c.monto),
            nota: '${c.veces} cobros',
          ),
      ],
    );
    final hormiga = _Seccion(
      icono: Icons.bug_report_outlined,
      titulo: 'Gastos hormiga',
      resumen: d.hormiga.isEmpty
          ? 'No vimos gastos chicos que se repitan mucho este mes. ¡Bien!'
          : '${formatoMonto(d.totalHormiga)} en los últimos '
                '${Deteccion.diasHormiga} días · al año serían '
                '${formatoMonto(d.hormigaAlAnio)}',
      bloqueado: bloqueado && d.hormiga.isNotEmpty,
      filas: [
        for (final h in d.hormiga)
          _Fila(
            icono: iconoParaCategoria(h.categoria),
            titulo: h.nombre,
            detalle: '${h.veces} veces · promedio ${formatoMonto(h.promedio)}',
            monto: formatoMonto(h.total),
            nota: '${formatoMonto(h.alAnio)} al año',
            color: AppColors.outflowCrimson,
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 860
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: recurrentes),
                const SizedBox(width: 24),
                Expanded(child: hormiga),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [recurrentes, const SizedBox(height: 22), hormiga],
            ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.icono,
    required this.titulo,
    required this.resumen,
    required this.filas,
    required this.bloqueado,
  });

  final IconData icono;
  final String titulo;
  final String resumen;
  final List<Widget> filas;
  final bool bloqueado;

  @override
  Widget build(BuildContext context) {
    final lista = Column(
      children: [
        for (final (i, f) in filas.indexed) ...[
          if (i > 0) Divider(height: 1, color: AppColors.glassStrokeStandard),
          f,
        ],
      ],
    );
    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, color: AppColors.acento),
              const SizedBox(width: 10),
              Expanded(child: Text(titulo, style: AppTextStyles.headlineSm)),
            ],
          ),
          const SizedBox(height: 6),
          // En Gratis el resumen (cuántos y cuánto) sí se ve: es lo que
          // invita a desbloquear el detalle.
          Text(
            resumen,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (filas.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (bloqueado) _Bloqueado(child: lista) else lista,
          ],
        ],
      ),
    );
  }
}

/// El detalle borroso con el botón para pasar a Plus.
class _Bloqueado extends StatelessWidget {
  const _Bloqueado({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: child,
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
              child: const Text('Ver el detalle con Plus'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.monto,
    required this.nota,
    this.color,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final String monto;
  final String nota;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface3ActiveGlass,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: AppColors.acento, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: AppTextStyles.bodyLg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  detalle,
                  style: AppTextStyles.bodySm.copyWith(
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
                monto,
                style: AppTextStyles.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color ?? AppColors.textPrimary,
                ),
              ),
              Text(
                nota,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Acceso desde Reportes: "Análisis inteligente · 2 cargos fijos · 1 gasto
/// hormiga".
class AccesoAnalisis extends ConsumerWidget {
  const AccesoAnalisis({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(deteccionProvider).value;
    final plan = ref.watch(membresiaProvider).value?.plan ?? PlanNero.gratis;
    final detalle = d == null || d.vacia
        ? 'Suscripciones, cargos fijos y gastos hormiga'
        : [
            if (d.recurrentes.isNotEmpty)
              '${d.recurrentes.length} '
                  '${d.recurrentes.length == 1 ? 'cargo fijo' : 'cargos fijos'}',
            if (d.hormiga.isNotEmpty)
              '${d.hormiga.length} '
                  '${d.hormiga.length == 1 ? 'gasto hormiga' : 'gastos hormiga'}',
          ].join(' · ');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/analisis'),
        child: GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          color: AppColors.secundario.withValues(alpha: 0.12),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.acento),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Análisis inteligente', style: AppTextStyles.bodyLg),
                    Text(
                      detalle,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (plan == PlanNero.gratis)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.acento.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Plus',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.acento,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: AppColors.acento),
            ],
          ),
        ),
      ),
    );
  }
}
