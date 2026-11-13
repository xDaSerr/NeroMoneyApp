import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/paleta_categorias.dart';
import '../../../core/utils/formato_monto.dart';
import '../../../core/widgets/piezas_movil.dart';
import '../../transactions/data/categoria.dart';
import '../../transactions/data/resumen_gastos.dart';
import '../../transactions/data/transaccion.dart';
import '../../transactions/providers/transacciones_providers.dart';
import '../data/periodo_reporte.dart';
import 'barras_flujo.dart' show LeyendaFlujo;
import 'dona_categorias.dart';
import 'grafica_flujo.dart';

/// Reportes en teléfono (diseño móvil del usuario): periodo, gastos e
/// ingresos lado a lado, balance, flujo de efectivo y el desglose por
/// categoría. Mismos cálculos que en escritorio (ResumenGastos,
/// totalPeriodo, calcularBuckets): solo cambia la distribución.
class ReportesMovil extends ConsumerStatefulWidget {
  const ReportesMovil({super.key});

  @override
  ConsumerState<ReportesMovil> createState() => _ReportesMovilState();
}

class _ReportesMovilState extends ConsumerState<ReportesMovil> {
  TipoPeriodo _tipo = TipoPeriodo.mes;
  int _offset = 0;
  TipoTransaccion _desglose = TipoTransaccion.gasto;

  @override
  Widget build(BuildContext context) {
    final rango = calcularRangoPeriodo(_tipo, _offset);
    final todas = ref.watch(
      transaccionesPorRangoProvider((rango.desde, rango.hasta)),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- ← Reportes / Entiende tu dinero. ---
              Row(
                children: [
                  IconButton(
                    tooltip: 'Volver',
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: TituloMovil(
                      titulo: 'Reportes',
                      subtitulo: 'Entiende tu dinero.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Semana / Mes / Año ---
                    SegmentadoMovil<TipoPeriodo>(
                      opciones: const {
                        TipoPeriodo.semana: 'Semana',
                        TipoPeriodo.mes: 'Mes',
                        TipoPeriodo.anio: 'Año',
                      },
                      valor: _tipo,
                      onCambiar: (t) => setState(() {
                        _tipo = t;
                        _offset = 0;
                      }),
                    ),
                    const SizedBox(height: 12),
                    // --- "< Noviembre 2026 >  EN CURSO" ---
                    _Navegador(
                      rango: rango,
                      onAnterior: () => setState(() => _offset--),
                      // Nunca se navega al futuro: no tiene movimientos.
                      onSiguiente: rango.esActual
                          ? null
                          : () => setState(() => _offset++),
                    ),
                    const SizedBox(height: 16),
                    todas.when(
                      data: (lista) => _contenido(lista, rango),
                      loading: () => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.acento,
                          ),
                        ),
                      ),
                      error: (e, _) => Text(
                        'No se pudieron cargar tus movimientos: $e',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.outflowCrimson,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenido(List<Transaccion> todas, RangoPeriodo rango) {
    // "Gasto neto" (descuenta reembolsos de la misma categoría): el mismo
    // número que Inicio y el asistente.
    final gastos = ResumenGastos.calcular(
      todas,
      desde: rango.desde,
      hasta: rango.hasta,
    );
    final ingresos = totalPeriodo(
      todas,
      TipoTransaccion.ingreso,
      desde: rango.desde,
      hasta: rango.hasta,
    );
    final porIngreso = totalPorCategoria(
      todas,
      TipoTransaccion.ingreso,
      desde: rango.desde,
      hasta: rango.hasta,
    );
    final balance = ingresos - gastos.total;
    final buckets = calcularBuckets(_tipo, rango, todas);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Gastos e ingresos lado a lado ---
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Total(
                  titulo: 'Gastos',
                  monto: gastos.total,
                  color: AppColors.outflowCrimson,
                  icono: Icons.south_east_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Total(
                  titulo: 'Ingresos',
                  monto: ingresos,
                  color: AppColors.inflowEmerald,
                  icono: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // --- Balance del periodo ---
        TarjetaMovil(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BALANCE DEL PERIODO',
                      style: AppTextStyles.labelCode.copyWith(letterSpacing: 2),
                    ),
                    Text('Ingresos menos gastos', style: AppTextStyles.bodyMd),
                  ],
                ),
              ),
              Text(
                '${balance < 0 ? '−' : '+'}${formatoMonto(balance.abs())}',
                style: AppTextStyles.numericHero.copyWith(
                  fontSize: 26,
                  color: balance >= 0
                      ? AppColors.inflowEmerald
                      : AppColors.outflowCrimson,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // --- Flujo de efectivo ---
        TarjetaMovil(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Flujo de efectivo', style: AppTextStyles.headlineSm),
              Text(switch (_tipo) {
                TipoPeriodo.semana => 'Ingresos y gastos por día',
                TipoPeriodo.mes => 'Ingresos y gastos por semana',
                TipoPeriodo.anio => 'Ingresos y gastos por mes',
              }, style: AppTextStyles.bodyMd),
              const SizedBox(height: 16),
              GraficaFlujo(buckets: buckets, altura: 200),
              const SizedBox(height: 12),
              const LeyendaFlujo(),
              if (ingresos <= 0.01 && gastos.total <= 0.01) ...[
                const SizedBox(height: 12),
                Text(
                  'Sin movimientos registrados en este periodo.',
                  style: AppTextStyles.bodyMd,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // --- Por categoría ---
        _PorCategoria(
          tipo: _desglose,
          gastos: gastos.porCategoria,
          ingresos: porIngreso,
          onCambiar: (t) => setState(() => _desglose = t),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03, end: 0);
  }
}

class _Navegador extends StatelessWidget {
  const _Navegador({
    required this.rango,
    required this.onAnterior,
    required this.onSiguiente,
  });

  final RangoPeriodo rango;
  final VoidCallback onAnterior;
  final VoidCallback? onSiguiente;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2Glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassStrokeHighlight),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Periodo anterior',
            onPressed: onAnterior,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    rango.etiqueta,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLg.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (rango.esActual) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.acento.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'EN CURSO',
                      style: AppTextStyles.labelCode.copyWith(
                        color: AppColors.acento,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Periodo siguiente',
            onPressed: onSiguiente,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.titulo,
    required this.monto,
    required this.color,
    required this.icono,
  });

  final String titulo;
  final double monto;
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return TarjetaMovil(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo.toUpperCase(),
                  style: AppTextStyles.labelCode.copyWith(letterSpacing: 1.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatoMonto(monto),
              style: AppTextStyles.numericHero.copyWith(
                fontSize: 26,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PorCategoria extends StatelessWidget {
  const _PorCategoria({
    required this.tipo,
    required this.gastos,
    required this.ingresos,
    required this.onCambiar,
  });

  final TipoTransaccion tipo;
  final Map<String, double> gastos;
  final Map<String, double> ingresos;
  final ValueChanged<TipoTransaccion> onCambiar;

  @override
  Widget build(BuildContext context) {
    final datos = tipo == TipoTransaccion.gasto ? gastos : ingresos;
    final total = datos.values.fold<double>(0, (a, v) => a + v);
    final colores = paletaCategorias;

    return TarjetaMovil(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Por categoría', style: AppTextStyles.headlineSm),
          const SizedBox(height: 12),
          SegmentadoMovil<TipoTransaccion>(
            opciones: {
              TipoTransaccion.gasto: 'Gastos (${gastos.length})',
              TipoTransaccion.ingreso: 'Ingresos (${ingresos.length})',
            },
            valor: tipo,
            onCambiar: onCambiar,
          ),
          const SizedBox(height: 18),
          if (datos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                tipo == TipoTransaccion.gasto
                    ? 'Todavía no tienes gastos en este periodo.'
                    : 'Todavía no tienes ingresos en este periodo.',
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            // --- Dona a la izquierda, lista a la derecha ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DonaCategorias(
                  entradas: datos.entries.toList(),
                  total: total,
                  colores: colores,
                  tamano: 130,
                  grosor: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (final (i, e) in datos.entries.indexed) ...[
                        if (i > 0) const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              iconoParaCategoria(e.key),
                              color: colores[i % colores.length],
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.key,
                                style: AppTextStyles.bodyMd.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(e.value / total * 100).round()}%',
                              style: AppTextStyles.bodyMd.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 26),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatoMonto(e.value),
                              style: AppTextStyles.bodySm,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
