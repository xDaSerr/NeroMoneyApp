import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'selector_periodo.dart';
import '../../../core/moneda/monedas_providers.dart';
import '../../analisis/analisis_screen.dart' show AccesoAnalisis;
import 'reportes_avanzados.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/paleta_categorias.dart';
import '../../../core/utils/formato_monto.dart';
import '../../../core/widgets/piezas_escritorio.dart';
import '../../transactions/data/categoria.dart';
import '../../transactions/data/resumen_gastos.dart';
import '../../transactions/data/transaccion.dart';
import '../../transactions/providers/transacciones_providers.dart';
import '../data/periodo_reporte.dart';
import 'barras_flujo.dart' show LeyendaFlujo;
import 'dona_categorias.dart';
import 'grafica_flujo.dart';

/// Reportes en ventana ancha (ver referencia de diseño del usuario): periodo
/// arriba a la derecha, tres totales (gastos, ingresos, balance), flujo de
/// efectivo con ejes y el desglose por categoría. Mismos cálculos que en
/// teléfono (ResumenGastos, totalPeriodo, calcularBuckets): solo cambia la
/// distribución.
class ReportesEscritorio extends ConsumerStatefulWidget {
  const ReportesEscritorio({super.key});

  @override
  ConsumerState<ReportesEscritorio> createState() => _ReportesEscritorioState();
}

class _ReportesEscritorioState extends ConsumerState<ReportesEscritorio> {
  SeleccionPeriodo _sel = const SeleccionPeriodo(TipoPeriodo.mes);

  TipoTransaccion _desglose = TipoTransaccion.gasto;

  @override
  Widget build(BuildContext context) {
    // Multimoneda: recalcular cuando cambian las cuentas o los tipos de cambio.
    ref.watch(conversorMonedaProvider);
    final rango = _sel.rango;
    final todas = ref.watch(
      transaccionesPorRangoProvider((rango.desde, rango.hasta)),
    );

    return Scaffold(
      body: SingleChildScrollView(
        padding: margenSeccionEscritorio,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoMaximoSeccion),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EncabezadoEscritorio(
                  etiqueta: 'Reportes',
                  titulo: 'Reportes',
                  subtitulo: 'Entiende en qué se va tu dinero.',
                  acciones: [
                    // --- Semana / Mes / Año ---
                    // Con un rango personalizado no queda marcado ninguno.
                    ControlSegmentado<TipoPeriodo?>(
                      opciones: const {
                        TipoPeriodo.dia: 'Día',
                        TipoPeriodo.semana: 'Semana',
                        TipoPeriodo.mes: 'Mes',
                        TipoPeriodo.anio: 'Año',
                      },
                      seleccionado: _sel.esPersonalizado ? null : _sel.tipo,
                      onCambiar: (t) =>
                          setState(() => _sel = SeleccionPeriodo(t!)),
                    ),
                    // --- "< Noviembre 2026 >" + EN CURSO ---
                    _NavegadorPeriodo(
                      etiqueta: rango.etiqueta,
                      esActual: rango.esActual,
                      onAnterior: () => setState(() => _sel = _sel.previa),
                      // Nunca se navega al futuro: no tiene movimientos.
                      onSiguiente: _sel.puedeAvanzar
                          ? () => setState(() => _sel = _sel.siguiente)
                          : null,
                      seleccion: _sel,
                      onAplicar: (s) => setState(() => _sel = s),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // --- Análisis inteligente (cargos fijos, gastos hormiga) ---
                const AccesoAnalisis(),
                const SizedBox(height: 24),
                todas.when(
                  data: (lista) => _contenido(lista, rango),
                  loading: () => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.acento),
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
    final buckets = calcularBuckets(_sel, todas);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Totales del periodo ---
        Row(
          children: [
            Expanded(
              child: _Total(titulo: 'Gastos totales', monto: gastos.total),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: _Total(
                titulo: 'Ingresos',
                monto: ingresos,
                color: AppColors.inflowEmerald,
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: _Total(
                titulo: 'Balance del periodo',
                monto: balance,
                color: balance >= 0
                    ? AppColors.inflowEmerald
                    : AppColors.outflowCrimson,
                nota: 'Ingresos menos gastos',
                conSigno: true,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Flujo de efectivo ---
            Expanded(
              flex: 13,
              child: TarjetaEscritorio(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Flujo de efectivo', style: AppTextStyles.headlineMd),
                    const SizedBox(height: 4),
                    Text(
                      _sel.tramo.descripcion,
                      style: AppTextStyles.bodyLg.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const LeyendaFlujo(),
                    const SizedBox(height: 20),
                    GraficaFlujo(buckets: buckets),
                    if (ingresos <= 0.01 || gastos.total <= 0.01) ...[
                      const SizedBox(height: 18),
                      _Nota(
                        ingresos <= 0.01 && gastos.total <= 0.01
                            ? 'Sin movimientos registrados en este periodo.'
                            : ingresos <= 0.01
                            ? 'Sin ingresos registrados en este periodo.'
                            : 'Sin gastos registrados en este periodo.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 22),
            // --- Desglose por categoría ---
            Expanded(
              flex: 9,
              child: _Desglose(
                tipo: _desglose,
                gastos: gastos.porCategoria,
                ingresos: porIngreso,
                onCambiar: (t) => setState(() => _desglose = t),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 80.ms, duration: 350.ms),
        const SizedBox(height: 32),
        // --- Comparación, tendencia de 12 meses (Plus) y tu año (Pro) ---
        ReportesAvanzados(seleccion: _sel, enColumnas: true),
      ],
    );
  }
}

class _NavegadorPeriodo extends StatelessWidget {
  const _NavegadorPeriodo({
    required this.etiqueta,
    required this.esActual,
    required this.onAnterior,
    required this.onSiguiente,
    required this.seleccion,
    required this.onAplicar,
  });

  final String etiqueta;
  final bool esActual;
  final VoidCallback onAnterior;
  final VoidCallback? onSiguiente;
  final SeleccionPeriodo seleccion;
  final ValueChanged<SeleccionPeriodo> onAplicar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface2Glass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassStrokeHighlight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Periodo anterior',
                onPressed: onAnterior,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              // --- La fecha: se estira hasta "Elegir periodo" ---
              BotonPeriodo(
                seleccion: seleccion,
                tipoBase: seleccion.tipo,
                onAplicar: onAplicar,
                boton: (context, abrir) => Tooltip(
                  message: 'Elegir fecha',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: abrir,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 190),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: AppColors.acento,
                          ),
                          const SizedBox(width: 8),
                          Text(etiqueta, style: AppTextStyles.bodyLg),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Periodo siguiente',
                onPressed: onSiguiente,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        if (esActual) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.acento.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'EN CURSO',
              style: AppTextStyles.labelCode.copyWith(color: AppColors.acento),
            ),
          ),
        ],
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.titulo,
    required this.monto,
    this.color,
    this.nota,
    this.conSigno = false,
  });

  final String titulo;
  final double monto;
  final Color? color;
  final String? nota;
  final bool conSigno;

  @override
  Widget build(BuildContext context) {
    final signo = conSigno ? (monto < 0 ? '−' : '+') : '';
    return TarjetaEscritorio(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: AppTextStyles.labelCode.copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 10),
          Text(
            '$signo${formatoMonto(monto.abs())}',
            style: AppTextStyles.numericHero.copyWith(
              fontSize: 38,
              color: color ?? AppColors.textPrimary,
            ),
          ),
          if (nota != null)
            Text(
              nota!,
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface3ActiveGlass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassStrokeStandard),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(texto, style: AppTextStyles.bodyMd),
        ],
      ),
    );
  }
}

class _Desglose extends StatelessWidget {
  const _Desglose({
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

    return TarjetaEscritorio(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Desglose por categoría', style: AppTextStyles.headlineMd),
          const SizedBox(height: 14),
          // --- Gastos / Ingresos ---
          ControlSegmentado<TipoTransaccion>(
            opciones: {
              TipoTransaccion.gasto: 'Gastos (${gastos.length})',
              TipoTransaccion.ingreso: 'Ingresos (${ingresos.length})',
            },
            seleccionado: tipo,
            onCambiar: onCambiar,
          ),
          const SizedBox(height: 22),
          if (datos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text(
                tipo == TipoTransaccion.gasto
                    ? 'Todavía no tienes gastos en este periodo.'
                    : 'Todavía no tienes ingresos en este periodo.',
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else ...[
            Center(
              child: DonaCategorias(
                entradas: datos.entries.toList(),
                total: total,
                colores: colores,
                tamano: 210,
                grosor: 34,
              ),
            ),
            const SizedBox(height: 24),
            for (final (i, e) in datos.entries.indexed) ...[
              if (i > 0)
                Divider(color: AppColors.glassStrokeStandard, height: 20),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colores[i % colores.length].withValues(
                        alpha: 0.18,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      iconoParaCategoria(e.key),
                      color: colores[i % colores.length],
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      e.key,
                      style: AppTextStyles.bodyLg,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    formatoMonto(e.value),
                    style: AppTextStyles.bodyLg.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${(e.value / total * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.bodyLg.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
