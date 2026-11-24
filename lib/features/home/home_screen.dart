import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/moneda/monedas_providers.dart';
import '../../core/router/app_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/paleta_categorias.dart';
import '../../core/utils/fecha_es.dart';
import '../../core/utils/formato_monto.dart';
import '../../core/widgets/boton_con_panel.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/piezas_movil.dart';
import '../accounts/data/cuenta.dart';
import '../accounts/providers/cuentas_providers.dart';
import '../accounts/widgets/cuenta_movil.dart';
import '../auth/providers/auth_providers.dart';
import '../onboarding/providers/perfil_providers.dart';
import '../presupuestos/widgets/tarjeta_planeacion_inicio.dart';
import '../libreta/widgets/tarjeta_libreta_inicio.dart';
import '../profile/data/saludo_usuario.dart';
import '../transactions/data/resumen_gastos.dart';
import '../transactions/data/transaccion.dart';
import '../transactions/providers/transacciones_providers.dart';
import '../transactions/widgets/fila_movimiento_movil.dart';
import '../transactions/widgets/panel_nuevo_movimiento.dart';
import 'providers/privacidad_inicio_provider.dart';
import 'widgets/inicio_escritorio.dart';

/// Inicio. En teléfono sigue el diseño móvil del usuario: patrimonio con
/// accesos rápidos, carrusel de cuentas, gastos del mes y últimos
/// movimientos, todo con datos reales. En ventana ancha usa
/// InicioEscritorio.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Multimoneda: recalcular cuando cambian las cuentas o los tipos de cambio.
    ref.watch(conversorMonedaProvider);
    if (esEscritorio(context)) return const InicioEscritorio();

    final cuentasAsync = ref.watch(cuentasProvider);
    final transacciones = ref.watch(transaccionesProvider).value ?? const [];
    final privacidad = ref.watch(privacidadInicioProvider);
    // No mostrar cifras durante la lectura de la preferencia guardada.
    final ocultar = privacidad.value ?? true;
    final perfil = ref.watch(perfilProvider).value;
    final saludo = datosDeSaludo(
      ref.watch(authStateChangesProvider).value,
      perfil?.apodo,
    );

    return Scaffold(
      body: SafeArea(
        // El margen inferior va dentro del scroll para que las tarjetas
        // pasen detrás de la barra flotante.
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            18,
            14,
            18,
            20 + espacioParaBarraFlotante(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EncabezadoMovil(),
              const SizedBox(height: 18),
              // --- Saludo: apodo > Google > correo (ver datosDeSaludo) ---
              Text(
                perfil?.esCumpleanos(DateTime.now()) ?? false
                    ? '¡Feliz cumpleaños, ${saludo.nombre}! 🎂'
                    : 'Hola, ${saludo.nombre} 👋',
                style: AppTextStyles.display.copyWith(fontSize: 30),
              ),
              Text(
                'Tu dinero, en orden.',
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              cuentasAsync.when(
                data: (cuentas) => _contenido(
                  context,
                  ref,
                  cuentas,
                  transacciones,
                  ocultar,
                  privacidad.isLoading,
                  perfil?.moneda ?? 'MXN',
                ),
                loading: () => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.acento),
                  ),
                ),
                error: (e, _) => Text(
                  'No se pudo cargar tu información: $e',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.outflowCrimson,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    WidgetRef ref,
    List<Cuenta> cuentas,
    List<Transaccion> transacciones,
    bool ocultar,
    bool cargandoPrivacidad,
    String moneda,
  ) {
    if (cuentas.isEmpty) return const _AvisoSinCuentas();
    // Patrimonio = solo dinero real; las tarjetas de crédito no entran
    // (ver Cuenta.efectoEnPatrimonio).
    final total = cuentas.fold<double>(
      0,
      (a, c) => a + c.efectoEnPatrimonioPrincipal,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaPatrimonioMovil(
          total: total,
          moneda: moneda,
          ocultar: ocultar,
          onAlternar: cargandoPrivacidad
              ? null
              : () => ref
                    .read(privacidadInicioProvider.notifier)
                    .alternar()
                    .catchError((Object _) {}),
          // --- Accesos rápidos: Ingreso / Gasto / Transferir / Analizar ---
          debajo: Row(
            children: [
              for (final (i, accion) in [
                ('Ingreso', Icons.add_rounded, TipoTransaccion.ingreso),
                ('Gasto', Icons.remove_rounded, TipoTransaccion.gasto),
              ].indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  // (se transforma en el panel "Crear movimiento")
                  child: BotonConPanel(
                    colorBoton: AppColors.surface1,
                    boton: (context, abrir) => _AccionRapida(
                      icono: accion.$2,
                      texto: accion.$1,
                      onTap: abrir,
                    ),
                    panel: (context, cerrar) => PanelNuevoMovimiento(
                      tipoInicial: accion.$3,
                      onCerrar: cerrar,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: _AccionRapida(
                  icono: Icons.swap_horiz_rounded,
                  texto: 'Transferir',
                  onTap: () => context.push('/transfer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AccionRapida(
                  icono: Icons.insights_rounded,
                  texto: 'Analizar',
                  onTap: () => context.push('/reports'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // --- "Tus cuentas" + "Ver todas (N) →" (cambia a la pestaña Cuentas) ---
        Row(
          children: [
            Expanded(
              child: Text('Tus cuentas', style: AppTextStyles.headlineMd),
            ),
            EnlaceVerTodo(
              texto: 'Ver todas (${cuentas.length})',
              onTap: () => context.go('/accounts'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // --- Carrusel de cuentas ---
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: cuentas.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: 290,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () =>
                    context.push('/accounts/detalle', extra: cuentas[i].id),
                child: CuentaMovil(cuenta: cuentas[i], ocultar: ocultar),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _GastosDelMes(transacciones: transacciones),
        // --- Presupuestos y metas (avisa al pasar del 80%) ---
        const TarjetaPlaneacionInicio(),
        // --- Libreta: solo si hay préstamos sin pagar ---
        const TarjetaLibretaInicio(),
        const SizedBox(height: 22),
        _UltimosMovimientos(transacciones: transacciones, cuentas: cuentas),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _AccionRapida extends StatelessWidget {
  const _AccionRapida({
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface3ActiveGlass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.glassStrokeHighlight),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icono, color: AppColors.acento, size: 26),
              const SizedBox(height: 4),
              Text(
                texto,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gastos del mes: total, barra de proporción con porcentajes y leyenda con
/// montos. Mismo cálculo (neteando reembolsos) que Reportes y el asistente.
class _GastosDelMes extends StatelessWidget {
  const _GastosDelMes({required this.transacciones});

  final List<Transaccion> transacciones;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final resumen = ResumenGastos.calcular(
      transacciones,
      desde: DateTime(hoy.year, hoy.month),
      hasta: DateTime(hoy.year, hoy.month + 1),
    );
    if (resumen.porCategoria.isEmpty) return const SizedBox.shrink();
    final total = resumen.total;
    final entradas = resumen.porCategoria.entries.toList();
    final visibles = entradas.take(4).toList();
    final resto = entradas.skip(4).fold<double>(0, (a, e) => a + e.value);
    if (resto > 0) visibles.add(MapEntry('Otros', resto));
    final colores = paletaCategorias;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: TarjetaMovil(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gastos de ${mesesEs[hoy.month - 1]}',
              style: AppTextStyles.headlineSm,
            ),
            Text(
              formatoMonto(total),
              style: AppTextStyles.numericHero.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 12),
            // --- Barra de proporción, con el porcentaje dentro ---
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 26,
                child: Row(
                  children: [
                    for (final (i, e) in visibles.indexed)
                      Expanded(
                        flex: (e.value * 1000 / total).round().clamp(1, 1000),
                        child: Container(
                          color: colores[i % colores.length],
                          alignment: Alignment.center,
                          child: e.value / total >= 0.08
                              ? Text(
                                  '${(e.value / total * 100).round()}%',
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // --- Leyenda: categoría y monto ---
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                for (final (i, e) in visibles.indexed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colores[i % colores.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(e.key, style: AppTextStyles.bodyLg),
                      const SizedBox(width: 8),
                      Text(
                        formatoMonto(e.value).replaceAll('.00', ''),
                        style: AppTextStyles.bodyLg.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UltimosMovimientos extends StatelessWidget {
  const _UltimosMovimientos({
    required this.transacciones,
    required this.cuentas,
  });

  final List<Transaccion> transacciones;
  final List<Cuenta> cuentas;

  @override
  Widget build(BuildContext context) {
    if (transacciones.isEmpty) return const SizedBox.shrink();
    final nombres = {for (final c in cuentas) c.id: c.nombre};
    final ultimos = transacciones.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- "Últimos movimientos" + "Ver todos →" (pestaña Movimientos) ---
        Row(
          children: [
            Expanded(
              child: Text(
                'Últimos movimientos',
                style: AppTextStyles.headlineMd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            EnlaceVerTodo(
              texto: 'Ver todos',
              onTap: () => context.go('/movements'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TarjetaMovil(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (final (i, t) in ultimos.indexed) ...[
                if (i > 0)
                  Divider(height: 1, color: AppColors.glassStrokeStandard),
                FilaMovimientoMovil(
                  transaccion: t,
                  detalle:
                      '${t.fecha.day} ${mesesEs[t.fecha.month - 1].substring(0, 3)} • ${nombres[t.cuentaId] ?? '—'}',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AvisoSinCuentas extends StatelessWidget {
  const _AvisoSinCuentas();

  @override
  Widget build(BuildContext context) {
    return TarjetaMovil(
      color: AppColors.secundario.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.secundarioClaro),
          const SizedBox(height: 10),
          Text(
            'Aún no tienes cuentas — agrega una para empezar a ver tu '
            'patrimonio y tus gastos aquí.',
            style: AppTextStyles.bodyLg,
          ),
          const SizedBox(height: 14),
          // --- Botón "Agregar cuenta" → pestaña Cuentas ---
          GradientButton(
            label: 'Agregar cuenta',
            onPressed: () => context.go('/accounts'),
          ),
        ],
      ),
    );
  }
}
