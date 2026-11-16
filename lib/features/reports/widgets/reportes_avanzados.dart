import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/moneda/monedas_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/fecha_es.dart';
import '../../../core/utils/formato_monto.dart';
import '../../../core/widgets/glass_card.dart';
import '../../planes/data/membresia.dart';
import '../../planes/providers/planes_providers.dart';
import '../../planes/widgets/bloqueo_plan.dart';
import '../../transactions/data/categoria.dart';
import '../../transactions/providers/transacciones_providers.dart';
import '../data/avanzados.dart';
import '../data/periodo_reporte.dart';
import 'barras_flujo.dart';
import 'grafica_flujo.dart';

/// Al final de Reportes: comparación con el periodo anterior y tendencia
/// de 12 meses (Plus), y "Tu año" con la proyección a diciembre (Pro).
class ReportesAvanzados extends ConsumerWidget {
  const ReportesAvanzados({
    super.key,
    required this.seleccion,
    this.enColumnas = false,
  });

  final SeleccionPeriodo seleccion;

  /// Escritorio: comparación y tendencia lado a lado.
  final bool enColumnas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(conversorMonedaProvider);
    final plan = ref.watch(membresiaProvider).value?.plan ?? PlanNero.gratis;
    final actual = seleccion.rango;
    final anterior = Comparacion.rangoAnterior(seleccion);
    final doce = rangoDoceMeses();
    final movComparacion = ref.watch(
      transaccionesPorRangoProvider((anterior.desde, actual.hasta)),
    );
    final movDoce = ref.watch(transaccionesPorRangoProvider(doce));

    final comparacion = _Tarjeta(
      icono: Icons.compare_arrows_rounded,
      titulo: 'Contra ${anterior.etiqueta.toLowerCase()}',
      child: movComparacion.when(
        data: (lista) =>
            _ComparacionVista(Comparacion.calcular(lista, actual, anterior)),
        loading: () => const _Cargando(),
        error: (_, _) => const _ErrorCarga(),
      ),
    );
    final tendencia = _Tarjeta(
      icono: Icons.show_chart_rounded,
      titulo: 'Tendencia de 12 meses',
      child: movDoce.when(
        data: (lista) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LeyendaFlujo(),
            const SizedBox(height: 12),
            // En pantallas angostas, 12 nombres de mes no caben: solo la
            // inicial ("E F M A…"). Sin LayoutBuilder: en escritorio va
            // dentro de IntrinsicHeight, que no lo admite.
            Builder(
              builder: (context) {
                final datos = tendenciaDoceMeses(lista);
                return GraficaFlujo(
                  altura: 200,
                  buckets: MediaQuery.sizeOf(context).width >= 560
                      ? datos
                      : [
                          for (final b in datos)
                            (
                              etiqueta: b.etiqueta.substring(0, 1),
                              ingreso: b.ingreso,
                              gasto: b.gasto,
                            ),
                        ],
                );
              },
            ),
          ],
        ),
        loading: () => const _Cargando(),
        error: (_, _) => const _ErrorCarga(),
      ),
    );
    final anio = _Tarjeta(
      icono: Icons.calendar_month_rounded,
      titulo: 'Tu ${DateTime.now().year}',
      etiqueta: 'Pro',
      child: movDoce.when(
        data: (lista) =>
            _AnioVista(ResumenAnio.calcular(lista, DateTime.now())),
        loading: () => const _Cargando(),
        error: (_, _) => const _ErrorCarga(),
      ),
    );

    Widget conPlan(Widget w, PlanNero necesario) =>
        plan.index >= necesario.index
        ? w
        : BloqueoPlan(plan: necesario, child: w);

    final plusSecciones = enColumnas
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: comparacion),
                const SizedBox(width: 22),
                Expanded(child: tendencia),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [comparacion, const SizedBox(height: 16), tendencia],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.insights_rounded, color: AppColors.acento),
            const SizedBox(width: 10),
            Text('Reportes avanzados', style: AppTextStyles.headlineMd),
          ],
        ),
        const SizedBox(height: 14),
        conPlan(plusSecciones, PlanNero.plus),
        const SizedBox(height: 16),
        conPlan(anio, PlanNero.pro),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.child,
    this.etiqueta,
  });

  final IconData icono;
  final String titulo;
  final Widget child;
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, color: AppColors.acento, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(titulo, style: AppTextStyles.headlineSm)),
              if (etiqueta != null)
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
                    etiqueta!,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.acento,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// "+12%" en rojo si subió el gasto, "−8%" en verde si bajó.
class _Cambio extends StatelessWidget {
  const _Cambio(this.cambio, {this.grande = false});

  final double? cambio;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final c = cambio;
    final estilo = (grande ? AppTextStyles.bodyLg : AppTextStyles.bodyMd)
        .copyWith(fontWeight: FontWeight.w700);
    if (c == null) {
      return Text(
        'nuevo',
        style: estilo.copyWith(color: AppColors.textSecondary),
      );
    }
    final sube = c > 0.005;
    final baja = c < -0.005;
    final color = sube
        ? AppColors.outflowCrimson
        : baja
        ? AppColors.inflowEmerald
        : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          sube
              ? Icons.arrow_upward_rounded
              : baja
              ? Icons.arrow_downward_rounded
              : Icons.remove_rounded,
          size: grande ? 18 : 15,
          color: color,
        ),
        Text(
          '${(c.abs() * 100).round()}%',
          style: estilo.copyWith(color: color),
        ),
      ],
    );
  }
}

class _ComparacionVista extends StatelessWidget {
  const _ComparacionVista(this.c);

  final Comparacion c;

  @override
  Widget build(BuildContext context) {
    if (c.totalActual == 0 && c.totalAnterior == 0) {
      return Text(
        'Sin gastos en estos periodos.',
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatoMonto(c.totalActual),
                    style: AppTextStyles.numericHero.copyWith(fontSize: 26),
                  ),
                  Text(
                    'antes ${formatoMonto(c.totalAnterior)}'
                    '${c.parcial ? ' al mismo día' : ''}',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _Cambio(c.cambio, grande: true),
          ],
        ),
        const SizedBox(height: 12),
        for (final cat in c.categorias.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  iconoParaCategoria(cat.categoria),
                  size: 18,
                  color: AppColors.acento,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(cat.categoria, style: AppTextStyles.bodyMd),
                ),
                Text(
                  formatoMonto(cat.actual),
                  style: AppTextStyles.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 64,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _Cambio(cat.cambio),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AnioVista extends StatelessWidget {
  const _AnioVista(this.r);

  final ResumenAnio r;

  @override
  Widget build(BuildContext context) {
    if (r.vacio) {
      return Text(
        'Aún no hay movimientos este año.',
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
      );
    }
    final datos = [
      ('Gastado en el año', formatoMonto(r.gasto), AppColors.outflowCrimson),
      ('Ingresos del año', formatoMonto(r.ingreso), AppColors.inflowEmerald),
      (
        r.ahorro >= 0 ? 'Ahorrado' : 'Gastaste de más',
        formatoMonto(r.ahorro.abs()),
        r.ahorro >= 0 ? AppColors.inflowEmerald : AppColors.outflowCrimson,
      ),
      (
        'Gasto promedio al mes',
        formatoMonto(r.gastoPromedioMensual),
        AppColors.textPrimary,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (etiqueta, valor, color) in datos)
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 150),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface3ActiveGlass,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        etiqueta,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        valor,
                        style: AppTextStyles.headlineSm.copyWith(color: color),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (r.mesMasCaro != null)
          _Linea(
            Icons.local_fire_department_outlined,
            'Tu mes más caro fue ${mesesEs[r.mesMasCaro! - 1]} '
            '(${formatoMonto(r.gastoMesMasCaro)}).',
          ),
        if (r.categoriaPrincipal != null)
          _Linea(
            iconoParaCategoria(r.categoriaPrincipal!),
            'En lo que más gastas: ${r.categoriaPrincipal} '
            '(${formatoMonto(r.gastoCategoriaPrincipal)}).',
          ),
        // --- Proyección: a este ritmo, cómo cierra el año ---
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.acento.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.acento.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.trending_up_rounded, color: AppColors.acento),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.ingreso <= 0
                      // Sin ingresos registrados no hay "ahorro" que proyectar.
                      ? 'A este ritmo cerrarás ${r.anio} con '
                            '${formatoMonto(r.proyeccionGasto)} gastados.'
                      : 'A este ritmo cerrarás ${r.anio} con '
                            '${formatoMonto(r.proyeccionGasto)} gastados y '
                            '${r.proyeccionAhorro >= 0 ? '${formatoMonto(r.proyeccionAhorro)} ahorrados' : '${formatoMonto(-r.proyeccionAhorro)} gastados de más'}.',
                  style: AppTextStyles.bodyMd,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.icono, this.texto);

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icono, size: 18, color: AppColors.acento),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: AppTextStyles.bodyMd)),
      ],
    ),
  );
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator(color: AppColors.acento)),
  );
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga();

  @override
  Widget build(BuildContext context) => Text(
    'No se pudieron cargar los datos.',
    style: AppTextStyles.bodyMd.copyWith(color: AppColors.outflowCrimson),
  );
}
