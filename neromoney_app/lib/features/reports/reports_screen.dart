import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/paleta_categorias.dart';
import '../../core/widgets/glass_card.dart';
import '../transactions/data/categoria.dart';
import '../transactions/data/resumen_gastos.dart';
import '../transactions/data/transaccion.dart';
import '../transactions/providers/transacciones_providers.dart';
import 'data/periodo_reporte.dart';
import 'widgets/barras_flujo.dart';
import 'widgets/dona_categorias.dart';

/// Reportes — sigue `12._reportes_y_estad_sticas` del Stitch (tarjetas de
/// gasto/ingreso con variación, flujo de efectivo, desglose por categoría),
/// pero solo con lo real: se omiten a propósito "Lucy Predictor" (cierre de
/// mes proyectado, "simular recorte de gastos"), "Cargos fijos y
/// suscripciones" (detección automática de recurrentes) y las etiquetas de
/// presupuesto por categoría ("dentro de presupuesto", "alerta de exceso")
/// — nada de eso existe de verdad todavía (no hay presupuestos ni detección
/// de recurrencias), ver CLAUDE.md → regla de fidelidad al Stitch. Todo lo
/// que sí se muestra aquí (totales, variación vs periodo anterior, flujo,
/// categorías) sale de `usuarios/{uid}/transacciones` real, sin inventar
/// ningún número.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  TipoPeriodo _tipo = TipoPeriodo.mes;
  int _offset = 0;
  TipoTransaccion _tipoDesglose = TipoTransaccion.gasto;

  @override
  Widget build(BuildContext context) {
    final rangoActual = calcularRangoPeriodo(_tipo, _offset);
    final rangoAnterior = calcularRangoPeriodo(_tipo, _offset - 1);
    // Una sola consulta que cubre el periodo actual Y el anterior (son
    // contiguos): más simple y más barato que pedir dos streams aparte.
    final transaccionesAsync = ref.watch(
      transaccionesPorRangoProvider((rangoAnterior.desde, rangoActual.hasta)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + espacioParaBarraFlotante(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Selector de periodo: Semana / Mes / Año ---
              Row(
                children: [
                  for (final tipo in TipoPeriodo.values) ...[
                    if (tipo != TipoPeriodo.values.first)
                      const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Text(
                          _nombrePeriodo(tipo),
                          textAlign: TextAlign.center,
                        ),
                        selected: _tipo == tipo,
                        onSelected: (_) => setState(() {
                          _tipo = tipo;
                          _offset = 0;
                        }),
                        selectedColor: AppColors.primaryCyan.withValues(
                          alpha: 0.2,
                        ),
                        backgroundColor: AppColors.surface3ActiveGlass,
                        labelStyle: AppTextStyles.bodySm.copyWith(
                          color: _tipo == tipo
                              ? AppColors.primaryCyan
                              : AppColors.textSecondary,
                        ),
                        side: BorderSide.none,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              // --- Navegador "< Octubre 2026 [EN CURSO] >" ---
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _offset -= 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          rangoActual.etiqueta,
                          style: AppTextStyles.bodyLg,
                          textAlign: TextAlign.center,
                        ),
                        if (rangoActual.esActual) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCyan.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'EN CURSO',
                              style: AppTextStyles.labelCode.copyWith(
                                color: AppColors.primaryCyan,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Nunca se navega al futuro: no tiene movimientos que mostrar.
                  IconButton(
                    onPressed: rangoActual.esActual
                        ? null
                        : () => setState(() => _offset += 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              transaccionesAsync.when(
                data: (todas) => _Contenido(
                  tipo: _tipo,
                  rangoActual: rangoActual,
                  rangoAnterior: rangoAnterior,
                  todas: todas,
                  tipoDesglose: _tipoDesglose,
                  onCambiarDesglose: (tipo) =>
                      setState(() => _tipoDesglose = tipo),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryCyan,
                    ),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'No se pudieron cargar tus movimientos: $e',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.outflowCrimson,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _nombrePeriodo(TipoPeriodo tipo) => switch (tipo) {
  TipoPeriodo.semana => 'Semana',
  TipoPeriodo.mes => 'Mes',
  TipoPeriodo.anio => 'Año',
};

/// El cuerpo del reporte, ya con los datos del rango cargados. Aparte de
/// `_ReportsScreenState.build` sobre todo para que los cálculos (que no son
/// triviales: comparación contra el periodo anterior, tramos del gráfico,
/// desglose por categoría) no vivan mezclados con el árbol de widgets del
/// selector/navegador de arriba.
class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.tipo,
    required this.rangoActual,
    required this.rangoAnterior,
    required this.todas,
    required this.tipoDesglose,
    required this.onCambiarDesglose,
  });

  final TipoPeriodo tipo;
  final RangoPeriodo rangoActual;
  final RangoPeriodo rangoAnterior;
  final List<Transaccion> todas;
  final TipoTransaccion tipoDesglose;
  final ValueChanged<TipoTransaccion> onCambiarDesglose;

  @override
  Widget build(BuildContext context) {
    // "Gasto neto" (descuenta reembolsos de la misma categoría) — mismo
    // cálculo que usa Lucy y "Gastos del mes" en Inicio, para que el número
    // de arriba y el desglose de abajo siempre coincidan.
    final gastoActual = ResumenGastos.calcular(
      todas,
      desde: rangoActual.desde,
      hasta: rangoActual.hasta,
    );
    final gastoAnterior = ResumenGastos.calcular(
      todas,
      desde: rangoAnterior.desde,
      hasta: rangoAnterior.hasta,
    );
    final ingresoActual = totalPeriodo(
      todas,
      TipoTransaccion.ingreso,
      desde: rangoActual.desde,
      hasta: rangoActual.hasta,
    );
    final ingresoAnterior = totalPeriodo(
      todas,
      TipoTransaccion.ingreso,
      desde: rangoAnterior.desde,
      hasta: rangoAnterior.hasta,
    );
    final ahorroNeto = ingresoActual - gastoActual.total;
    final tasaAhorro = ingresoActual > 0.01
        ? (ahorroNeto / ingresoActual * 100)
        : null;

    final categoriasGastoActual = gastoActual.porCategoria;
    final categoriasIngresoActual = totalPorCategoria(
      todas,
      TipoTransaccion.ingreso,
      desde: rangoActual.desde,
      hasta: rangoActual.hasta,
    );
    final desglose = tipoDesglose == TipoTransaccion.gasto
        ? categoriasGastoActual
        : categoriasIngresoActual;
    final totalDesglose = tipoDesglose == TipoTransaccion.gasto
        ? gastoActual.total
        : ingresoActual;

    final buckets = calcularBuckets(tipo, rangoActual, todas);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Tarjetas "Gastos Totales" / "Ingresos", con variación real vs
        // el periodo anterior ---
        Row(
          children: [
            Expanded(
              child: _TarjetaResumen(
                titulo: 'Gastos totales',
                monto: gastoActual.total,
                anterior: gastoAnterior.total,
                colorMonto: AppColors.textPrimary,
                subirEsBueno: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TarjetaResumen(
                titulo: 'Ingresos',
                monto: ingresoActual,
                anterior: ingresoAnterior,
                colorMonto: AppColors.inflowEmerald,
                subirEsBueno: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // --- Ahorro neto + tasa de ahorro ---
        GlassCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AHORRO NETO GENERADO', style: AppTextStyles.labelCode),
                    const SizedBox(height: 6),
                    Text(
                      '\$${ahorroNeto.toStringAsFixed(2)}',
                      style: AppTextStyles.headlineMd.copyWith(
                        color: ahorroNeto >= 0
                            ? AppColors.inflowEmerald
                            : AppColors.outflowCrimson,
                      ),
                    ),
                  ],
                ),
              ),
              if (tasaAhorro != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'TASA DE AHORRO',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelCode,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tasaAhorro.toStringAsFixed(0)}%',
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.primaryCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        // --- Flujo de efectivo: ingresos vs gastos por tramo ---
        Text('Flujo de efectivo', style: AppTextStyles.headlineSm),
        const SizedBox(height: 4),
        Text(_subtituloFlujo(tipo), style: AppTextStyles.bodySm),
        const SizedBox(height: 12),
        const LeyendaFlujo(),
        const SizedBox(height: 16),
        GlassCard(child: BarrasFlujo(buckets: buckets)),
        const SizedBox(height: 28),
        // --- Desglose por categoría (Gastos/Ingresos, elegible) ---
        Text('Desglose por categoría', style: AppTextStyles.headlineSm),
        const SizedBox(height: 4),
        Text('Distribución de este periodo', style: AppTextStyles.bodySm),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ChipDesglose(
              label: 'Gastos (${categoriasGastoActual.length})',
              seleccionado: tipoDesglose == TipoTransaccion.gasto,
              onTap: () => onCambiarDesglose(TipoTransaccion.gasto),
            ),
            _ChipDesglose(
              label: 'Ingresos (${categoriasIngresoActual.length})',
              seleccionado: tipoDesglose == TipoTransaccion.ingreso,
              onTap: () => onCambiarDesglose(TipoTransaccion.ingreso),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (desglose.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              tipoDesglose == TipoTransaccion.gasto
                  ? 'Todavía no tienes gastos en este periodo.'
                  : 'Todavía no tienes ingresos en este periodo.',
              style: AppTextStyles.bodyMd,
            ),
          )
        else ...[
          Center(
            child: DonaCategorias(
              entradas: desglose.entries.toList(),
              total: totalDesglose,
              colores: paletaCategorias,
            ),
          ),
          const SizedBox(height: 24),
          for (final (i, entrada) in desglose.entries.indexed)
            _FilaCategoria(
              color: paletaCategorias[i % paletaCategorias.length],
              icono: iconoParaCategoria(entrada.key),
              categoria: entrada.key,
              monto: entrada.value,
              porcentaje: totalDesglose > 0.01
                  ? entrada.value / totalDesglose * 100
                  : 0,
            ),
        ],
      ],
    );
  }
}

String _subtituloFlujo(TipoPeriodo tipo) => switch (tipo) {
  TipoPeriodo.semana => 'Ingresos vs gastos por día',
  TipoPeriodo.mes => 'Ingresos vs gastos por semana',
  TipoPeriodo.anio => 'Ingresos vs gastos por mes',
};

/// El texto y color de la variación vs el periodo anterior (ej. "↘ -12%" en
/// verde si un gasto bajó, o en rojo si subió) — `null` cuando no hay una
/// base real con qué comparar (el periodo anterior estaba en $0).
({String texto, Color color})? _delta(
  double actual,
  double anterior, {
  required bool subirEsBueno,
}) {
  if (anterior <= 0.01) return null;
  final cambioPorcentaje = (actual - anterior) / anterior * 100;
  final subio = cambioPorcentaje >= 0;
  final esBueno = subio == subirEsBueno;
  return (
    texto:
        '${subio ? '↗' : '↘'} ${subio ? '+' : ''}${cambioPorcentaje.toStringAsFixed(0)}%',
    color: esBueno ? AppColors.inflowEmerald : AppColors.outflowCrimson,
  );
}

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({
    required this.titulo,
    required this.monto,
    required this.anterior,
    required this.colorMonto,
    required this.subirEsBueno,
  });

  final String titulo;
  final double monto;
  final double anterior;
  final Color colorMonto;
  final bool subirEsBueno;

  @override
  Widget build(BuildContext context) {
    final delta = _delta(monto, anterior, subirEsBueno: subirEsBueno);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo.toUpperCase(),
                  style: AppTextStyles.labelCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (delta != null)
                Text(
                  delta.texto,
                  style: AppTextStyles.labelSm.copyWith(color: delta.color),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${monto.toStringAsFixed(2)}',
            style: AppTextStyles.headlineSm.copyWith(color: colorMonto),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'vs \$${anterior.toStringAsFixed(2)} antes',
            style: AppTextStyles.bodySm,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ChipDesglose extends StatelessWidget {
  const _ChipDesglose({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryCyan.withValues(alpha: 0.2),
      backgroundColor: AppColors.surface3ActiveGlass,
      labelStyle: AppTextStyles.bodySm.copyWith(
        color: seleccionado ? AppColors.primaryCyan : AppColors.textSecondary,
      ),
      side: BorderSide.none,
    );
  }
}

/// Una fila del desglose: ícono de la categoría (`iconoParaCategoria`, la
/// misma que ya usa `MovimientoTile`), nombre, monto y una barra con su
/// proporción sobre el total del periodo — sin inventar "presupuesto" ni
/// "consumido": ese concepto no existe en la app todavía.
class _FilaCategoria extends StatelessWidget {
  const _FilaCategoria({
    required this.color,
    required this.icono,
    required this.categoria,
    required this.monto,
    required this.porcentaje,
  });

  final Color color;
  final IconData icono;
  final String categoria;
  final double monto;
  final double porcentaje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        categoria,
                        style: AppTextStyles.bodyLg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '\$${monto.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyLg,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (porcentaje / 100).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: AppColors.surface3ActiveGlass,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${porcentaje.toStringAsFixed(0)}% del total',
                  style: AppTextStyles.bodySm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
