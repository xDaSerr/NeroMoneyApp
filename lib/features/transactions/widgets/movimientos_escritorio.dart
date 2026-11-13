import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/fecha_es.dart';
import '../../../core/utils/formato_monto.dart';
import '../../../core/widgets/boton_con_panel.dart';
import '../../../core/widgets/piezas_escritorio.dart';
import '../../accounts/data/cuenta.dart';
import '../../accounts/providers/cuentas_providers.dart';
import '../data/categoria.dart';
import '../data/periodo_movimientos.dart';
import '../data/transaccion.dart';
import '../movements_screen.dart';
import '../providers/transacciones_providers.dart';
import 'panel_nuevo_movimiento.dart';

/// Movimientos en ventana ancha: buscador, filtros por cuenta, periodo y
/// tipo, y una tabla paginada (ver referencia de diseño del usuario). En
/// teléfono sigue la lista con deslizar para borrar (MovementsScreen).
class MovimientosEscritorio extends ConsumerStatefulWidget {
  const MovimientosEscritorio({super.key});

  @override
  ConsumerState<MovimientosEscritorio> createState() =>
      _MovimientosEscritorioState();
}

class _MovimientosEscritorioState extends ConsumerState<MovimientosEscritorio> {
  static const _porPagina = 8;

  final _busqueda = TextEditingController();
  String? _cuentaId; // null = todas
  PeriodoMovimientos _periodo = PeriodoMovimientos.todo;
  TipoFiltroMovimientos _tipo = TipoFiltroMovimientos.todos;
  bool _recientesPrimero = true;
  int _pagina = 0;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  /// Cualquier cambio de filtro regresa a la primera página.
  void _filtrar(VoidCallback cambio) => setState(() {
    cambio();
    _pagina = 0;
  });

  List<Transaccion> _aplicarFiltros(List<Transaccion> todas) {
    final texto = _busqueda.text.trim().toLowerCase();
    final lista = todas.where((t) {
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
      if (texto.isNotEmpty &&
          !t.descripcion.toLowerCase().contains(texto) &&
          !t.categoria.toLowerCase().contains(texto)) {
        return false;
      }
      return true;
    }).toList();
    lista.sort(
      (a, b) => _recientesPrimero
          ? b.fecha.compareTo(a.fecha)
          : a.fecha.compareTo(b.fecha),
    );
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final movimientosAsync = ref.watch(
      transaccionesPorRangoProvider(_periodo.rango),
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
                  titulo: 'Movimientos',
                  subtitulo: 'Consulta y organiza tu actividad.',
                  acciones: [
                    // --- Botón "Nuevo movimiento" → alta manual ---
                    // (se transforma en el panel "Crear movimiento")
                    BotonConPanel(
                      colorBoton: AppColors.acento,
                      boton: (context, abrir) => BotonContorno(
                        texto: 'Nuevo movimiento',
                        icono: Icons.add_rounded,
                        relleno: true,
                        onTap: abrir,
                      ),
                      panel: (context, cerrar) =>
                          PanelNuevoMovimiento(onCerrar: cerrar),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _filtros(cuentas),
                const SizedBox(height: 24),
                movimientosAsync.when(
                  data: (todas) => _tabla(_aplicarFiltros(todas), cuentas),
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
          ).animate().fadeIn(duration: 300.ms),
        ),
      ),
    );
  }

  Widget _filtros(List<Cuenta> cuentas) {
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // --- Buscador: por concepto o categoría ---
        SizedBox(
          width: 320,
          child: TextField(
            controller: _busqueda,
            onChanged: (_) => _filtrar(() {}),
            style: AppTextStyles.bodyLg,
            decoration: InputDecoration(
              hintText: 'Buscar movimiento…',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        // --- Filtro por cuenta ---
        MenuDesplegable<String?>(
          icono: Icons.credit_card_outlined,
          valor: _cuentaId,
          opciones: {
            null: 'Todas las cuentas',
            for (final c in cuentas) c.id: c.nombre,
          },
          onCambiar: (id) => _filtrar(() => _cuentaId = id),
        ),
        // --- Filtro por periodo ---
        MenuDesplegable<PeriodoMovimientos>(
          icono: Icons.calendar_today_rounded,
          valor: _periodo,
          opciones: {for (final p in PeriodoMovimientos.values) p: p.nombre},
          onCambiar: (p) => _filtrar(() => _periodo = p),
        ),
        // --- Todos / Ingresos / Gastos ---
        ControlSegmentado<TipoFiltroMovimientos>(
          opciones: const {
            TipoFiltroMovimientos.todos: 'Todos',
            TipoFiltroMovimientos.ingresos: 'Ingresos',
            TipoFiltroMovimientos.gastos: 'Gastos',
          },
          seleccionado: _tipo,
          onCambiar: (t) => _filtrar(() => _tipo = t),
        ),
      ],
    );
  }

  Widget _tabla(List<Transaccion> lista, List<Cuenta> cuentas) {
    final cuentasPorId = {for (final c in cuentas) c.id: c};
    final paginas = (lista.length / _porPagina).ceil().clamp(1, 1 << 30);
    final pagina = _pagina.clamp(0, paginas - 1);
    final visibles = lista.skip(pagina * _porPagina).take(_porPagina).toList();

    return TarjetaEscritorio(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        children: [
          // --- Encabezados (FECHA ordena: recientes primero o al revés) ---
          _Fila(
            encabezado: true,
            fecha: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () =>
                  _filtrar(() => _recientesPrimero = !_recientesPrimero),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('FECHA', style: _estiloEncabezado),
                  const SizedBox(width: 6),
                  Icon(
                    _recientesPrimero
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            concepto: Text('CONCEPTO', style: _estiloEncabezado),
            categoria: Text('CATEGORÍA', style: _estiloEncabezado),
            cuenta: Text('CUENTA', style: _estiloEncabezado),
            importe: Text(
              'IMPORTE',
              style: _estiloEncabezado,
              textAlign: TextAlign.right,
            ),
            menu: const SizedBox.shrink(),
          ),
          if (visibles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                lista.isEmpty && _busqueda.text.isEmpty && _cuentaId == null
                    ? 'Aún no tienes movimientos en este periodo.'
                    : 'Ningún movimiento coincide con estos filtros.',
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          for (final (i, t) in visibles.indexed)
            _filaMovimiento(t, cuentasPorId)
                .animate(key: ValueKey('${t.id}-$pagina'))
                .fadeIn(delay: (30 * i).ms, duration: 220.ms)
                .slideX(begin: 0.02, end: 0),
          const SizedBox(height: 14),
          // --- Pie: conteo y paginación ---
          Row(
            children: [
              Text.rich(
                TextSpan(
                  style: AppTextStyles.bodyMd,
                  children: [
                    const TextSpan(text: 'Mostrando '),
                    TextSpan(
                      text: '${visibles.length} de ${lista.length}',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    const TextSpan(text: ' movimientos'),
                  ],
                ),
              ),
              const Spacer(),
              BotonContorno(
                texto: 'Anterior',
                icono: Icons.chevron_left_rounded,
                color: AppColors.textSecondary,
                onTap: pagina > 0
                    ? () => setState(() => _pagina = pagina - 1)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  '${pagina + 1} de $paginas',
                  style: AppTextStyles.bodyLg,
                ),
              ),
              BotonContorno(
                texto: 'Siguiente',
                icono: Icons.chevron_right_rounded,
                iconoAlFinal: true,
                onTap: pagina < paginas - 1
                    ? () => setState(() => _pagina = pagina + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle get _estiloEncabezado =>
      AppTextStyles.labelCode.copyWith(letterSpacing: 2);

  Widget _filaMovimiento(Transaccion t, Map<String, Cuenta> cuentasPorId) {
    final esIngreso = t.tipo == TipoTransaccion.ingreso;
    final nombreCuenta = cuentasPorId[t.cuentaId]?.nombre ?? 'Cuenta eliminada';
    final concepto = t.esTransferencia
        ? 'Transferencia'
        : (t.descripcion.isEmpty ? t.categoria : t.descripcion);
    final cuenta = t.esTransferencia
        ? (esIngreso
              ? '${cuentasPorId[t.cuentaContraparteId]?.nombre ?? '—'} → $nombreCuenta'
              : '$nombreCuenta → ${cuentasPorId[t.cuentaContraparteId]?.nombre ?? '—'}')
        : nombreCuenta;
    final colorImporte = t.esTransferencia
        ? AppColors.acento
        : (esIngreso ? AppColors.inflowEmerald : AppColors.outflowCrimson);

    return _Fila(
      fecha: Text(_fecha(t.fecha), style: AppTextStyles.bodyLg),
      concepto: Text(
        concepto,
        style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      categoria: Align(
        alignment: Alignment.centerLeft,
        child: PildoraCategoria(
          texto: t.esTransferencia ? 'Transferencia' : t.categoria,
          icono: t.esTransferencia
              ? Icons.swap_horiz_rounded
              : iconoParaCategoria(t.categoria),
          color: t.esTransferencia
              ? AppColors.acento
              : colorDeCategoria(t.categoria, esIngreso: esIngreso),
        ),
      ),
      cuenta: Row(
        children: [
          Icon(
            Icons.credit_card_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cuenta,
              style: AppTextStyles.bodyLg,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      importe: Text(
        '${esIngreso ? '+' : '−'}${formatoMonto(t.monto)}',
        textAlign: TextAlign.right,
        style: AppTextStyles.bodyLg.copyWith(
          color: colorImporte,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      // --- Menú "⋯": eliminar (o deshacer la transferencia completa) ---
      menu: PopupMenuButton<void>(
        tooltip: 'Opciones',
        color: AppColors.surface1,
        icon: Icon(Icons.more_horiz_rounded, color: AppColors.textSecondary),
        itemBuilder: (_) => [
          PopupMenuItem(
            onTap: () => eliminarMovimiento(context, ref, t),
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.outflowCrimson,
                ),
                const SizedBox(width: 10),
                Text(
                  t.esTransferencia
                      ? 'Deshacer transferencia'
                      : 'Eliminar movimiento',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fecha(DateTime f) =>
      '${f.day} ${mesesEs[f.month - 1].substring(0, 3)} ${f.year}';
}

/// Una fila de la tabla con sus 6 columnas en proporciones fijas, para que
/// encabezados y filas queden alineados.
class _Fila extends StatefulWidget {
  const _Fila({
    required this.fecha,
    required this.concepto,
    required this.categoria,
    required this.cuenta,
    required this.importe,
    required this.menu,
    this.encabezado = false,
  });

  final Widget fecha;
  final Widget concepto;
  final Widget categoria;
  final Widget cuenta;
  final Widget importe;
  final Widget menu;
  final bool encabezado;

  @override
  State<_Fila> createState() => _FilaState();
}

class _FilaState extends State<_Fila> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: widget.encabezado ? 16 : 10,
        ),
        decoration: BoxDecoration(
          color: _encima && !widget.encabezado
              ? AppColors.surface3ActiveGlass
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            bottom: BorderSide(color: AppColors.glassStrokeStandard),
          ),
        ),
        child: Row(
          children: [
            Expanded(flex: 13, child: widget.fecha),
            Expanded(flex: 20, child: widget.concepto),
            Expanded(flex: 19, child: widget.categoria),
            Expanded(flex: 18, child: widget.cuenta),
            Expanded(flex: 14, child: widget.importe),
            SizedBox(width: 56, child: Center(child: widget.menu)),
          ],
        ),
      ),
    );
  }
}
