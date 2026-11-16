import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/moneda/conversor_moneda.dart';
import '../../core/moneda/monedas_providers.dart';
import '../../core/router/app_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/fecha_es.dart';
import '../../core/utils/formato_monto.dart';
import '../../core/widgets/boton_con_panel.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/piezas_escritorio.dart';
import '../home/providers/privacidad_inicio_provider.dart';
import '../onboarding/widgets/currency_picker.dart';
import '../transactions/data/categoria.dart';
import '../transactions/data/periodo_movimientos.dart';
import '../transactions/data/transaccion.dart';
import '../transactions/providers/transacciones_providers.dart';
import '../transactions/widgets/panel_nuevo_movimiento.dart';
import 'data/cuenta.dart';
import 'providers/cuentas_providers.dart';
import 'widgets/editar_cuenta_sheet.dart';
import 'widgets/estilo_cuenta.dart';

/// Etiqueta del Hero de la tarjeta: la misma en la lista de Cuentas y aquí,
/// para que la tarjeta "vuele" de una pantalla a la otra.
String heroDeCuenta(String id) => 'cuenta-$id';

/// Detalle de una cuenta (diseño del usuario, nov. 2026): a la izquierda la
/// tarjeta, accesos rápidos y detalles; a la derecha sus movimientos con
/// buscador y filtros. En teléfono, todo en una columna.
class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({super.key, required this.cuentaId});

  final String cuentaId;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  final _busqueda = TextEditingController();
  PeriodoMovimientos _periodo = PeriodoMovimientos.todo;
  TipoFiltroMovimientos _tipo = TipoFiltroMovimientos.todos;
  int _visibles = 8;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  List<Transaccion> _filtrar(List<Transaccion> todas) {
    final (desde, hasta) = _periodo.rango;
    final texto = _busqueda.text.trim().toLowerCase();
    return todas.where((t) {
      if (t.fecha.isBefore(desde) || !t.fecha.isBefore(hasta)) return false;
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
    }).toList();
  }

  void _editar(Cuenta cuenta) => mostrarEditorDeCuenta(
    context: context,
    cuenta: cuenta,
    onGuardar: (actualizada) =>
        ref.read(cuentasRepositoryProvider).actualizarCuenta(actualizada),
  );

  Future<void> _confirmarEliminar(Cuenta cuenta) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('¿Eliminar esta cuenta?'),
        content: Text(
          'Se elimina "${cuenta.nombre}". Sus movimientos ya registrados NO se '
          'borran, pero dejarán de tener una cuenta asociada.',
          style: AppTextStyles.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.outflowCrimson),
            ),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await ref.read(cuentasRepositoryProvider).eliminarCuenta(cuenta.id);
      if (mounted) context.go('/accounts');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(conversorMonedaProvider);
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final cuenta = cuentas.where((c) => c.id == widget.cuentaId).firstOrNull;

    // La cuenta se pudo haber borrado desde otra pantalla o dispositivo.
    if (cuenta == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cuenta')),
        body: Center(
          child: Text('Esta cuenta ya no existe.', style: AppTextStyles.bodyMd),
        ),
      );
    }

    final ancho = esEscritorio(context);
    final privacidad = ref.watch(privacidadInicioProvider);
    final ocultar = privacidad.value ?? true;
    final movimientos = ref.watch(transaccionesPorCuentaProvider(cuenta.id));

    final tarjeta = Hero(
      tag: heroDeCuenta(cuenta.id),
      // En el vuelo no hay Material: sin esto el texto sale subrayado.
      flightShuttleBuilder: (_, animacion, _, _, destino) =>
          Material(type: MaterialType.transparency, child: destino.widget),
      child: _TarjetaCuenta(
        cuenta: cuenta,
        ocultar: ocultar,
        onAlternar: privacidad.isLoading
            ? null
            : () => ref
                  .read(privacidadInicioProvider.notifier)
                  .alternar()
                  .catchError((Object _) {}),
      ),
    );
    final accesos = _AccesosRapidos(cuenta: cuenta);
    final detalles = _Detalles(
      cuenta: cuenta,
      onAjustar: () => _editar(cuenta),
    );
    final lista = _ListaMovimientos(
      busqueda: _busqueda,
      periodo: _periodo,
      tipo: _tipo,
      visibles: _visibles,
      compacta: !ancho,
      movimientos: movimientos.whenData(_filtrar),
      onBuscar: () => setState(() => _visibles = 8),
      onPeriodo: (p) => setState(() {
        _periodo = p;
        _visibles = 8;
      }),
      onTipo: (t) => setState(() {
        _tipo = t;
        _visibles = 8;
      }),
      onVerMas: () => setState(() => _visibles += 10),
    );

    // Entrada escalonada: cada bloque aparece un poco después del anterior.
    Widget entrada(Widget w, int orden) => w
        .animate()
        .fadeIn(delay: (90 * orden).ms, duration: 380.ms)
        .slideY(
          begin: 0.06,
          end: 0,
          delay: (90 * orden).ms,
          duration: 420.ms,
          curve: Curves.easeOutCubic,
        );

    final encabezado = _Encabezado(
      cuenta: cuenta,
      ancho: ancho,
      onEditar: () => _editar(cuenta),
      onEliminar: () => _confirmarEliminar(cuenta),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: ancho
              ? margenSeccionEscritorio
              : EdgeInsets.fromLTRB(
                  18,
                  10,
                  18,
                  24 + espacioParaBarraFlotante(context),
                ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: anchoMaximoSeccion),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  entrada(encabezado, 0),
                  SizedBox(height: ancho ? 26 : 18),
                  if (ancho)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 390,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              tarjeta,
                              const SizedBox(height: 22),
                              entrada(accesos, 1),
                              const SizedBox(height: 22),
                              entrada(detalles, 2),
                            ],
                          ),
                        ),
                        const SizedBox(width: 26),
                        Expanded(child: entrada(lista, 2)),
                      ],
                    )
                  else ...[
                    tarjeta,
                    const SizedBox(height: 16),
                    entrada(accesos, 1),
                    const SizedBox(height: 16),
                    entrada(lista, 2),
                    const SizedBox(height: 16),
                    entrada(detalles, 3),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Cuentas / Efectivo", el nombre grande y las acciones.
class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.cuenta,
    required this.ancho,
    required this.onEditar,
    required this.onEliminar,
  });

  final Cuenta cuenta;
  final bool ancho;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final esCredito = cuenta.tipo == TipoCuenta.credito;
    final menu = PopupMenuButton<String>(
      tooltip: 'Más opciones',
      color: AppColors.surface1,
      onSelected: (v) => v == 'eliminar' ? onEliminar() : onEditar(),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'ajustar', child: Text('Ajustar saldo')),
        PopupMenuItem(
          value: 'eliminar',
          child: Text(
            'Eliminar cuenta',
            style: TextStyle(color: AppColors.outflowCrimson),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassStrokeHighlight),
        ),
        child: Icon(Icons.more_horiz_rounded, color: AppColors.textPrimary),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!ancho)
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 2),
            child: IconButton(
              tooltip: 'Volver',
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/accounts'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Migas: "Cuentas / Efectivo" ---
              if (ancho)
                Row(
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => context.go('/accounts'),
                        child: Text(
                          'Cuentas',
                          style: AppTextStyles.bodyLg.copyWith(
                            color: AppColors.acento,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '   /   ',
                      style: AppTextStyles.bodyLg.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        cuenta.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLg,
                      ),
                    ),
                  ],
                ),
              if (ancho) const SizedBox(height: 4),
              Text(
                cuenta.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.display.copyWith(
                  fontSize: ancho ? 44 : 30,
                ),
              ),
              Text(
                esCredito
                    ? 'Tu línea de crédito, bajo control.'
                    : 'Tu dinero disponible, bajo control.',
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: ancho ? 18 : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (ancho) ...[
          BotonContorno(
            texto: 'Editar cuenta',
            icono: Icons.edit_outlined,
            color: AppColors.textPrimary,
            onTap: onEditar,
          ),
          const SizedBox(width: 12),
        ] else
          IconButton(
            tooltip: 'Editar cuenta',
            onPressed: onEditar,
            icon: const Icon(Icons.edit_outlined),
          ),
        menu,
      ],
    );
  }
}

/// La tarjeta de la cuenta: saldo (con el ojo para ocultarlo) y moneda.
class _TarjetaCuenta extends StatelessWidget {
  const _TarjetaCuenta({
    required this.cuenta,
    required this.ocultar,
    required this.onAlternar,
  });

  final Cuenta cuenta;
  final bool ocultar;
  final VoidCallback? onAlternar;

  @override
  Widget build(BuildContext context) {
    final color = colorDeCuenta(cuenta);
    final esCredito = cuenta.tipo == TipoCuenta.credito;
    final limite = cuenta.limiteCredito;
    final deuda = cuenta.deudaActual ?? 0;
    final uso = esCredito && limite != null && limite > 0
        ? (deuda / limite).clamp(0.0, 1.0)
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              color.withValues(alpha: 0.48),
              AppColors.fondoTarjetaFisica,
            ),
            Color.alphaBlend(
              color.withValues(alpha: 0.14),
              AppColors.fondoTarjetaFisica,
            ),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Icon(
                  iconoDeTipo(cuenta.tipo),
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cuenta.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineMd.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      [
                        cuenta.tipo.etiqueta.toUpperCase(),
                        if (cuenta.ultimos4Digitos?.isNotEmpty ?? false)
                          '•••• ${cuenta.ultimos4Digitos}',
                      ].join('  '),
                      style: AppTextStyles.labelCode.copyWith(
                        color: Colors.white70,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            esCredito ? 'DISPONIBLE' : 'SALDO DISPONIBLE',
            style: AppTextStyles.labelCode.copyWith(
              color: Colors.white,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  // Alineado a la izquierda (por defecto lo centra).
                  layoutBuilder: (actual, anteriores) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...anteriores, ?actual],
                  ),
                  transitionBuilder: (hijo, a) =>
                      FadeTransition(opacity: a, child: hijo),
                  child: ocultar
                      ? Text(
                          '●  ●  ●  ●  ●  ●',
                          key: const ValueKey('oculto'),
                          semanticsLabel: 'Saldo oculto',
                          style: AppTextStyles.headlineMd.copyWith(
                            color: Colors.white,
                            fontSize: 22,
                          ),
                        )
                      : FittedBox(
                          key: const ValueKey('visible'),
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatoMonto(cuenta.saldoActual),
                            style: AppTextStyles.numericHero.copyWith(
                              color: Colors.white,
                              fontSize: 34,
                            ),
                          ),
                        ),
                ),
              ),
              IconButton(
                tooltip: ocultar ? 'Mostrar saldo' : 'Ocultar saldo',
                onPressed: onAlternar,
                icon: Icon(
                  ocultar
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          Text(
            ConversorMoneda.monedaDeCuenta(cuenta.id),
            style: AppTextStyles.labelCode.copyWith(
              color: Colors.white70,
              letterSpacing: 2.5,
            ),
          ),
          if (uso != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: uso,
                minHeight: 7,
                color: color,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ocultar
                  ? 'Deuda oculta'
                  : 'Debes ${formatoMonto(deuda)} de ${formatoMonto(limite!)}',
              style: AppTextStyles.bodySm.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ingreso / Gasto (el panel ya viene con esta cuenta) / Transferir.
class _AccesosRapidos extends StatelessWidget {
  const _AccesosRapidos({required this.cuenta});

  final Cuenta cuenta;

  @override
  Widget build(BuildContext context) {
    Widget panel(String texto, IconData icono, TipoTransaccion tipo) =>
        BotonConPanel(
          colorBoton: AppColors.surface1,
          boton: (context, abrir) =>
              _Acceso(texto: texto, icono: icono, onTap: abrir),
          panel: (context, cerrar) => PanelNuevoMovimiento(
            tipoInicial: tipo,
            cuentaInicial: cuenta.id,
            onCerrar: cerrar,
          ),
        );

    return Row(
      children: [
        Expanded(
          child: panel('Ingreso', Icons.add_rounded, TipoTransaccion.ingreso),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: panel('Gasto', Icons.remove_rounded, TipoTransaccion.gasto),
        ),
        if (cuenta.permiteTransferencias) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _Acceso(
              texto: 'Transferir',
              icono: Icons.swap_horiz_rounded,
              onTap: () => context.push('/transfer'),
            ),
          ),
        ],
      ],
    );
  }
}

class _Acceso extends StatelessWidget {
  const _Acceso({
    required this.texto,
    required this.icono,
    required this.onTap,
  });

  final String texto;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface3ActiveGlass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.glassStrokeHighlight),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icono, color: AppColors.acento, size: 30),
              const SizedBox(height: 6),
              Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Detalles de la cuenta": tipo, moneda, datos de crédito y "Ajustar
/// saldo".
class _Detalles extends StatelessWidget {
  const _Detalles({required this.cuenta, required this.onAjustar});

  final Cuenta cuenta;
  final VoidCallback onAjustar;

  @override
  Widget build(BuildContext context) {
    final codigo = ConversorMoneda.monedaDeCuenta(cuenta.id);
    final nombreMoneda = monedasDisponibles
        .where((m) => m.codigo == codigo)
        .firstOrNull
        ?.nombre;
    final filas = <(String, String)>[
      ('Tipo', cuenta.tipo.etiqueta),
      ('Moneda', nombreMoneda == null ? codigo : '$nombreMoneda · $codigo'),
      if (cuenta.ultimos4Digitos?.isNotEmpty ?? false)
        ('Terminación', '•••• ${cuenta.ultimos4Digitos}'),
      if (cuenta.limiteCredito != null)
        ('Límite de crédito', formatoMonto(cuenta.limiteCredito!)),
      if (cuenta.deudaActual != null)
        ('Deuda actual', formatoMonto(cuenta.deudaActual!)),
      if (cuenta.diasParaCorte != null)
        ('Próximo corte', 'En ${cuenta.diasParaCorte} días'),
      if (cuenta.diaLimitePago != null)
        ('Límite de pago', 'Día ${cuenta.diaLimitePago}'),
    ];
    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Detalles de la cuenta', style: AppTextStyles.headlineSm),
          const SizedBox(height: 8),
          for (final (etiqueta, valor) in filas) ...[
            Divider(height: 1, color: AppColors.glassStrokeStandard),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Text(etiqueta, style: AppTextStyles.bodyLg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      valor,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.bodyLg,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Divider(height: 1, color: AppColors.glassStrokeStandard),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAjustar,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: Icon(Icons.tune_rounded, color: AppColors.acento),
              label: Text(
                'Ajustar saldo',
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.acento),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Movimientos de esta cuenta": buscador, periodo, tipo y la tabla.
class _ListaMovimientos extends StatelessWidget {
  const _ListaMovimientos({
    required this.busqueda,
    required this.periodo,
    required this.tipo,
    required this.visibles,
    required this.compacta,
    required this.movimientos,
    required this.onBuscar,
    required this.onPeriodo,
    required this.onTipo,
    required this.onVerMas,
  });

  final TextEditingController busqueda;
  final PeriodoMovimientos periodo;
  final TipoFiltroMovimientos tipo;
  final int visibles;
  final bool compacta;
  final AsyncValue<List<Transaccion>> movimientos;
  final VoidCallback onBuscar;
  final ValueChanged<PeriodoMovimientos> onPeriodo;
  final ValueChanged<TipoFiltroMovimientos> onTipo;
  final VoidCallback onVerMas;

  @override
  Widget build(BuildContext context) {
    final buscador = TextField(
      controller: busqueda,
      onChanged: (_) => onBuscar(),
      style: AppTextStyles.bodyLg,
      decoration: InputDecoration(
        hintText: 'Buscar movimiento',
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        filled: true,
        fillColor: AppColors.surface2Glass,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.glassStrokeHighlight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.glassStrokeHighlight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.acento),
        ),
      ),
    );
    final selectorPeriodo = MenuDesplegable<PeriodoMovimientos>(
      icono: Icons.calendar_today_rounded,
      valor: periodo,
      opciones: {for (final p in PeriodoMovimientos.values) p: p.nombre},
      onCambiar: onPeriodo,
    );

    return GlassCard(
      borderRadius: 24,
      padding: EdgeInsets.all(compacta ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Movimientos de esta cuenta', style: AppTextStyles.headlineMd),
          const SizedBox(height: 16),
          if (compacta) ...[
            buscador,
            const SizedBox(height: 10),
            selectorPeriodo,
          ] else
            Row(
              children: [
                Expanded(flex: 3, child: buscador),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: selectorPeriodo),
              ],
            ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: ControlSegmentado<TipoFiltroMovimientos>(
              opciones: const {
                TipoFiltroMovimientos.todos: 'Todos',
                TipoFiltroMovimientos.ingresos: 'Ingresos',
                TipoFiltroMovimientos.gastos: 'Gastos',
              },
              seleccionado: tipo,
              onCambiar: onTipo,
            ),
          ),
          const SizedBox(height: 16),
          movimientos.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(30),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.acento),
              ),
            ),
            error: (e, _) => Text(
              'No se pudieron cargar los movimientos.',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.outflowCrimson,
              ),
            ),
            data: (lista) {
              if (lista.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    busqueda.text.isEmpty &&
                            tipo == TipoFiltroMovimientos.todos &&
                            periodo == PeriodoMovimientos.todo
                        ? 'Todavía no hay movimientos en esta cuenta.'
                        : 'Ningún movimiento coincide con estos filtros.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }
              final mostrados = lista.take(visibles).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!compacta)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 4, 10),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: _Cabecera('CONCEPTO')),
                          Expanded(flex: 2, child: _Cabecera('FECHA')),
                          Expanded(
                            flex: 3,
                            child: _Cabecera('IMPORTE', derecha: true),
                          ),
                        ],
                      ),
                    ),
                  Divider(height: 1, color: AppColors.glassStrokeStandard),
                  for (final (i, t) in mostrados.indexed)
                    _FilaMovimiento(transaccion: t, compacta: compacta)
                        .animate()
                        .fadeIn(delay: (35 * (i % 10)).ms, duration: 260.ms)
                        .slideX(begin: 0.03, end: 0, duration: 260.ms),
                  if (lista.length > visibles)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: onVerMas,
                          iconAlignment: IconAlignment.end,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.acento,
                          ),
                          label: Text(
                            'Ver más movimientos',
                            style: AppTextStyles.bodyLg.copyWith(
                              color: AppColors.acento,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera(this.texto, {this.derecha = false});

  final String texto;
  final bool derecha;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    textAlign: derecha ? TextAlign.right : TextAlign.left,
    style: AppTextStyles.labelCode.copyWith(letterSpacing: 2),
  );
}

class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({required this.transaccion, required this.compacta});

  final Transaccion transaccion;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final t = transaccion;
    final esIngreso = t.tipo == TipoTransaccion.ingreso;
    final concepto = t.descripcion.trim().isEmpty
        ? t.categoria
        : '${t.descripcion.trim()[0].toUpperCase()}${t.descripcion.trim().substring(1)}';
    final fecha =
        '${t.fecha.day} ${mesesEs[t.fecha.month - 1].substring(0, 3)}';
    final monto = Text(
      '${esIngreso ? '+' : '−'}${ConversorMoneda.formato(t.monto, t.cuentaId)}',
      textAlign: TextAlign.right,
      style: AppTextStyles.bodyLg.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: compacta ? null : 18,
        color: esIngreso ? AppColors.inflowEmerald : AppColors.textPrimary,
      ),
    );
    final icono = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface3ActiveGlass,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        t.esTransferencia
            ? Icons.swap_horiz_rounded
            : iconoParaCategoria(t.categoria),
        size: 20,
        color: AppColors.textPrimary,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.glassStrokeStandard),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: compacta
          ? Row(
              children: [
                icono,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        concepto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLg,
                      ),
                      Text(
                        '$fecha · ${t.categoria}',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                monto,
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      icono,
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          concepto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyLg.copyWith(fontSize: 17),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    fecha,
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(flex: 3, child: monto),
              ],
            ),
    );
  }
}
