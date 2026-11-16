import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/moneda/monedas_providers.dart';
import '../../../core/router/app_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/fecha_es.dart';
import '../../../core/widgets/boton_con_panel.dart';
import '../../../core/widgets/piezas_escritorio.dart' show MenuDesplegable;
import '../../../core/widgets/piezas_movil.dart';
import '../../accounts/data/cuenta.dart';
import '../../exportar/exportar_dialogo.dart';
import '../../accounts/providers/cuentas_providers.dart';
import '../data/periodo_movimientos.dart';
import '../data/transaccion.dart';
import '../movements_screen.dart' show eliminarMovimiento;
import '../providers/transacciones_providers.dart';
import 'fila_movimiento_movil.dart';
import 'panel_nuevo_movimiento.dart';

/// Movimientos en teléfono (diseño móvil del usuario): buscador, filtros y
/// los movimientos agrupados por día. Deslizar a la izquierda elimina (con
/// confirmación, ver eliminarMovimiento).
class MovimientosMovil extends ConsumerStatefulWidget {
  const MovimientosMovil({super.key});

  @override
  ConsumerState<MovimientosMovil> createState() => _MovimientosMovilState();
}

class _MovimientosMovilState extends ConsumerState<MovimientosMovil> {
  final _busqueda = TextEditingController();
  String? _cuentaId; // null = todas
  PeriodoMovimientos _periodo = PeriodoMovimientos.todo;
  TipoFiltroMovimientos _tipo = TipoFiltroMovimientos.todos;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  List<Transaccion> _filtrar(List<Transaccion> todas) {
    final texto = _busqueda.text.trim().toLowerCase();
    return todas.where((t) {
      if (_cuentaId != null &&
          t.cuentaId != _cuentaId &&
          t.cuentaContraparteId != _cuentaId) {
        return false;
      }
      if (_tipo == TipoFiltroMovimientos.ingresos &&
          t.tipo != TipoTransaccion.ingreso) {
        return false;
      }
      if (_tipo == TipoFiltroMovimientos.gastos &&
          t.tipo != TipoTransaccion.gasto) {
        return false;
      }
      return texto.isEmpty ||
          t.descripcion.toLowerCase().contains(texto) ||
          t.categoria.toLowerCase().contains(texto);
    }).toList()..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  @override
  Widget build(BuildContext context) {
    // Multimoneda: recalcular cuando cambian las cuentas o los tipos de cambio.
    ref.watch(conversorMonedaProvider);
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final movimientos = ref.watch(
      transaccionesPorRangoProvider(_periodo.rango),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              sliver: SliverList.list(
                children: [
                  const EncabezadoMovil(),
                  const SizedBox(height: 18),
                  TituloMovil(
                    titulo: 'Movimientos',
                    subtitulo: 'Tu actividad, al día.',
                    accion: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- Exportar a Excel/CSV (Plus) o PDF (Pro) ---
                        IconButton(
                          tooltip: 'Exportar',
                          color: AppColors.acento,
                          onPressed: () => mostrarDialogoExportar(context, ref),
                          icon: const Icon(Icons.download_rounded),
                        ),
                        // --- "+ Nuevo": se transforma en "Crear movimiento" ---
                        BotonConPanel(
                          colorBoton: AppColors.acento,
                          boton: (context, abrir) =>
                              BotonAccionMovil(texto: 'Nuevo', onTap: abrir),
                          panel: (context, cerrar) =>
                              PanelNuevoMovimiento(onCerrar: cerrar),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // --- Buscador: por concepto o categoría ---
                  TextField(
                    controller: _busqueda,
                    onChanged: (_) => setState(() {}),
                    style: AppTextStyles.bodyLg,
                    decoration: InputDecoration(
                      hintText: 'Buscar movimiento…',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(
                          color: AppColors.glassStrokeHighlight,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: AppColors.acento),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // --- Todos / Ingresos / Gastos ---
                  SegmentadoMovil<TipoFiltroMovimientos>(
                    opciones: const {
                      TipoFiltroMovimientos.todos: 'Todos',
                      TipoFiltroMovimientos.ingresos: 'Ingresos',
                      TipoFiltroMovimientos.gastos: 'Gastos',
                    },
                    valor: _tipo,
                    onCambiar: (t) => setState(() => _tipo = t),
                  ),
                  const SizedBox(height: 12),
                  // --- Cuenta y periodo ---
                  Row(
                    children: [
                      Expanded(
                        child: MenuDesplegable<String?>(
                          icono: Icons.credit_card_outlined,
                          valor: _cuentaId,
                          opciones: {
                            null: 'Todas las cuentas',
                            for (final c in cuentas) c.id: c.nombre,
                          },
                          onCambiar: (id) => setState(() => _cuentaId = id),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MenuDesplegable<PeriodoMovimientos>(
                          icono: Icons.calendar_today_rounded,
                          valor: _periodo,
                          opciones: {
                            for (final p in PeriodoMovimientos.values)
                              p: p.nombre,
                          },
                          onCambiar: (p) => setState(() => _periodo = p),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            ...movimientos.when(
              data: (todas) => _dias(_filtrar(todas), cuentas),
              loading: () => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.acento),
                    ),
                  ),
                ),
              ],
              error: (e, _) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
            SliverToBoxAdapter(
              child: SizedBox(height: espacioParaBarraFlotante(context)),
            ),
          ],
        ),
      ),
    );
  }

  /// Una tarjeta por día ("10 de noviembre"), de lo más reciente a lo más
  /// viejo.
  List<Widget> _dias(List<Transaccion> lista, List<Cuenta> cuentas) {
    if (lista.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
            child: Text(
              _busqueda.text.isEmpty && _cuentaId == null
                  ? 'Aún no tienes movimientos en este periodo. Toca "Nuevo" '
                        'para registrar el primero.'
                  : 'Ningún movimiento coincide con estos filtros.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ];
    }
    final nombres = {for (final c in cuentas) c.id: c.nombre};
    final dias = <DateTime, List<Transaccion>>{};
    for (final t in lista) {
      dias
          .putIfAbsent(
            DateTime(t.fecha.year, t.fecha.month, t.fecha.day),
            () => [],
          )
          .add(t);
    }
    final anioActual = DateTime.now().year;
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        sliver: SliverList.separated(
          itemCount: dias.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            final dia = dias.keys.elementAt(i);
            final delDia = dias[dia]!;
            return TarjetaMovil(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    child: Text(
                      '${dia.day} de ${mesesEs[dia.month - 1]}'
                      '${dia.year == anioActual ? '' : ' de ${dia.year}'}',
                      style: AppTextStyles.headlineSm,
                    ),
                  ),
                  Divider(height: 1, color: AppColors.glassStrokeStandard),
                  for (final (j, t) in delDia.indexed) ...[
                    if (j > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Divider(
                          height: 1,
                          color: AppColors.glassStrokeStandard,
                        ),
                      ),
                    // --- Deslizar a la izquierda: eliminar (con confirmación) ---
                    Dismissible(
                      key: ValueKey(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        color: AppColors.outflowCrimson.withValues(alpha: 0.85),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      // El borrado real se hace aquí y no en onDismissed:
                      // así la fila solo desaparece cuando ya se borró.
                      confirmDismiss: (_) =>
                          eliminarMovimiento(context, ref, t),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: FilaMovimientoMovil(
                          transaccion: t,
                          detalle: t.esTransferencia
                              ? (nombres[t.cuentaId] ?? '—')
                              : '${t.categoria} • ${nombres[t.cuentaId] ?? '—'}',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(
              delay: (40 * i.clamp(0, 6)).ms,
              duration: 250.ms,
            );
          },
        ),
      ),
    ];
  }
}
