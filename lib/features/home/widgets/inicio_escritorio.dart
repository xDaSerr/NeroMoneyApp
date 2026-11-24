import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/moneda/monedas_providers.dart';
import '../../../core/router/app_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/paleta_categorias.dart';
import '../../../core/utils/fecha_es.dart';
import '../../../core/utils/formato_monto.dart';
import '../../../core/widgets/boton_con_panel.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../../accounts/data/cuenta.dart';
import '../../accounts/providers/cuentas_providers.dart';
import '../../accounts/widgets/cuenta_tile.dart';
import '../../onboarding/providers/perfil_providers.dart';
import '../../profile/data/saludo_usuario.dart';
import '../../reports/widgets/dona_categorias.dart';
import '../../transactions/data/resumen_gastos.dart';
import '../../transactions/data/transaccion.dart';
import '../../transactions/providers/transacciones_providers.dart';
import '../../transactions/widgets/movimiento_tile.dart';
import '../../transactions/widgets/panel_nuevo_movimiento.dart';
import '../../presupuestos/widgets/tarjeta_planeacion_inicio.dart';
import '../../libreta/widgets/tarjeta_libreta_inicio.dart';
import '../providers/privacidad_inicio_provider.dart';

/// Inicio en ventanas anchas (ver HomeScreen): los mismos datos que el de
/// teléfono, acomodados en dos columnas como en el diseño de escritorio que
/// pidió el usuario — patrimonio y cuentas a la izquierda; gastos del mes y
/// últimos movimientos a la derecha.
class InicioEscritorio extends ConsumerWidget {
  const InicioEscritorio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Multimoneda: recalcular cuando cambian las cuentas o los tipos de cambio.
    ref.watch(conversorMonedaProvider);
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
    final hoy = DateTime.now();

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          36,
          32,
          36,
          32 + espacioParaBarraFlotante(context),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Encabezado: "RESUMEN GENERAL", saludo y mes en curso ---
                Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RESUMEN GENERAL',
                                style: AppTextStyles.labelCode.copyWith(
                                  color: AppColors.acento,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                perfil?.esCumpleanos(DateTime.now()) ?? false
                                    ? '¡Feliz cumpleaños, ${saludo.nombre}! 🎂'
                                    : 'Hola, ${saludo.nombre} 👋',
                                style: AppTextStyles.display.copyWith(
                                  fontSize: 44,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tu dinero, en un solo lugar.',
                                style: AppTextStyles.bodyLg.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Solo informa el mes que se está mostrando: Inicio no
                        // cambia de periodo (eso vive en Reportes), así que no
                        // se dibuja como un selector que no hace nada.
                        _Chip(
                          icono: Icons.calendar_today_rounded,
                          texto: '${mesCapitalizado(hoy.month)} ${hoy.year}',
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.08, end: 0),
                const SizedBox(height: 28),
                cuentasAsync.when(
                  data: (cuentas) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Columna izquierda: patrimonio y cuentas ---
                      Expanded(
                        flex: 11,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (cuentas.isEmpty)
                              const _AvisoSinCuentas()
                            else ...[
                              _TarjetaPatrimonio(
                                total: cuentas.fold<double>(
                                  0,
                                  (acc, c) =>
                                      acc + c.efectoEnPatrimonioPrincipal,
                                ),
                                moneda: perfil?.moneda ?? 'MXN',
                                ocultar: ocultar,
                                cargandoPrivacidad: privacidad.isLoading,
                                onAlternar: () =>
                                    _alternarPrivacidad(context, ref),
                              ),
                              const SizedBox(height: 32),
                              _CuentasEnCuadricula(
                                cuentas: cuentas,
                                ocultar: ocultar,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 28),
                      // --- Columna derecha: gastos del mes y movimientos ---
                      Expanded(
                        flex: 8,
                        child: Column(
                          children: [
                            _GastosDelMes(transacciones: transacciones),
                            // --- Presupuestos y metas ---
                            const TarjetaPlaneacionInicio(
                              padding: EdgeInsets.all(24),
                              radio: 24,
                            ),
                            const TarjetaLibretaInicio(
                              padding: EdgeInsets.all(24),
                              radio: 24,
                              margenArriba: 18,
                            ),
                            const SizedBox(height: 22),
                            _UltimosMovimientos(
                              transacciones: transacciones,
                              cuentas: cuentas,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                  loading: () => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
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
      ),
    );
  }

  Future<void> _alternarPrivacidad(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(privacidadInicioProvider.notifier).alternar();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar la preferencia para la próxima vez.',
          ),
        ),
      );
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2Glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassStrokeHighlight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(texto, style: AppTextStyles.bodyLg),
        ],
      ),
    );
  }
}

/// Patrimonio total con la moneda debajo y los cuatro accesos rápidos como
/// botones cuadrados de vidrio.
class _TarjetaPatrimonio extends StatelessWidget {
  const _TarjetaPatrimonio({
    required this.total,
    required this.moneda,
    required this.ocultar,
    required this.cargandoPrivacidad,
    required this.onAlternar,
  });

  final double total;
  final String moneda;
  final bool ocultar;
  final bool cargandoPrivacidad;
  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: AppColors.secundario.withValues(alpha: 0.12),
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'PATRIMONIO TOTAL',
                  style: AppTextStyles.labelCode.copyWith(letterSpacing: 2),
                ),
              ),
              // --- Ojo: oculta patrimonio e importes de las cuentas ---
              IconButton(
                tooltip: ocultar
                    ? 'Mostrar patrimonio y saldos'
                    : 'Ocultar patrimonio y saldos',
                color: AppColors.acento,
                iconSize: 28,
                icon: Icon(
                  ocultar
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: cargandoPrivacidad ? null : onAlternar,
              ),
            ],
          ),
          Text(
            ocultar ? '••••••' : formatoMonto(total),
            semanticsLabel: ocultar ? 'Patrimonio oculto' : null,
            style: AppTextStyles.numericHero.copyWith(fontSize: 52),
          ),
          const SizedBox(height: 4),
          Text(
            moneda,
            style: AppTextStyles.labelCode.copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 28),
          // --- Accesos rápidos: Ingreso / Gasto / Transferir / Analizar ---
          Row(
            children: [
              Expanded(
                // (se transforma en el panel "Crear movimiento")
                child: BotonConPanel(
                  colorBoton: AppColors.surface1,
                  boton: (context, abrir) => _AccionRapida(
                    icono: Icons.add_rounded,
                    texto: 'Ingreso',
                    onTap: abrir,
                  ),
                  panel: (context, cerrar) => PanelNuevoMovimiento(
                    tipoInicial: TipoTransaccion.ingreso,
                    onCerrar: cerrar,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                // (se transforma en el panel "Crear movimiento")
                child: BotonConPanel(
                  colorBoton: AppColors.surface1,
                  boton: (context, abrir) => _AccionRapida(
                    icono: Icons.remove_rounded,
                    texto: 'Gasto',
                    onTap: abrir,
                  ),
                  panel: (context, cerrar) => PanelNuevoMovimiento(
                    tipoInicial: TipoTransaccion.gasto,
                    onCerrar: cerrar,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _AccionRapida(
                  icono: Icons.swap_horiz_rounded,
                  texto: 'Transferir',
                  onTap: () => context.push('/transfer'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _AccionRapida(
                  icono: Icons.insights_rounded,
                  texto: 'Analizar',
                  onTap: () => context.push('/reports'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccionRapida extends StatefulWidget {
  const _AccionRapida({
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  State<_AccionRapida> createState() => _AccionRapidaState();
}

class _AccionRapidaState extends State<_AccionRapida> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 18),
          transform: Matrix4.translationValues(0, _encima ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: _encima
                ? AppColors.acento.withValues(alpha: 0.10)
                : AppColors.surface3ActiveGlass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _encima
                  ? AppColors.acento.withValues(alpha: 0.5)
                  : AppColors.glassStrokeHighlight,
            ),
          ),
          child: Column(
            children: [
              Icon(widget.icono, color: AppColors.acento, size: 28),
              const SizedBox(height: 8),
              Text(widget.texto, style: AppTextStyles.bodyLg),
            ],
          ),
        ),
      ),
    );
  }
}

class _CuentasEnCuadricula extends StatelessWidget {
  const _CuentasEnCuadricula({required this.cuentas, required this.ocultar});

  final List<Cuenta> cuentas;
  final bool ocultar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Encabezado "Tus cuentas y bolsillos" + "Ver todas" ---
        Row(
          children: [
            Text('Tus cuentas y bolsillos', style: AppTextStyles.headlineMd),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surface3ActiveGlass,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.glassStrokeStandard),
              ),
              child: Text('${cuentas.length}', style: AppTextStyles.labelCode),
            ),
            const Spacer(),
            _EnlaceFlecha(
              texto: 'Ver todas',
              onTap: () => context.go('/accounts'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // --- Cuadrícula de tarjetas: 2 o 3 por fila según el espacio ---
        LayoutBuilder(
          builder: (context, restricciones) {
            const separacion = 18.0;
            final columnas = restricciones.maxWidth >= 900 ? 3 : 2;
            final ancho =
                (restricciones.maxWidth - separacion * (columnas - 1)) /
                columnas;
            return Wrap(
              spacing: separacion,
              runSpacing: separacion,
              children: [
                for (final cuenta in cuentas)
                  SizedBox(
                    width: ancho,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () =>
                          context.push('/accounts/detalle', extra: cuenta.id),
                      child: CuentaTile(
                        cuenta: cuenta,
                        ocultarImportes: ocultar,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GastosDelMes extends StatelessWidget {
  const _GastosDelMes({required this.transacciones});

  final List<Transaccion> transacciones;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    // Mismo cálculo (neteando reembolsos por categoría) que Inicio en
    // teléfono, Reportes y Lucy — ver ResumenGastos.
    final resumen = ResumenGastos.calcular(
      transacciones,
      desde: DateTime(hoy.year, hoy.month, 1),
      hasta: DateTime(hoy.year, hoy.month + 1, 1),
    );
    if (resumen.porCategoria.isEmpty) return const SizedBox.shrink();
    final entradas = resumen.porCategoria.entries.toList();
    final visibles = entradas.take(4).toList();
    final resto = entradas.skip(4).fold<double>(0, (a, e) => a + e.value);
    if (resto > 0) visibles.add(MapEntry('Otros', resto));
    final colores = paletaCategorias;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gastos de ${mesesEs[hoy.month - 1]}',
              style: AppTextStyles.headlineSm,
            ),
            const SizedBox(height: 4),
            Text(
              formatoMonto(resumen.total),
              style: AppTextStyles.numericHero.copyWith(fontSize: 34),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                DonaCategorias(
                  entradas: visibles,
                  total: resumen.total,
                  colores: colores,
                  tamano: 150,
                  grosor: 26,
                ),
                const SizedBox(width: 24),
                // --- Leyenda: categoría y monto ---
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < visibles.length; i++) ...[
                        if (i > 0)
                          Divider(
                            color: AppColors.glassStrokeStandard,
                            height: 18,
                          ),
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: colores[i % colores.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                visibles[i].key,
                                style: AppTextStyles.bodyLg,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              formatoMonto(visibles[i].value),
                              style: AppTextStyles.bodyLg.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
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
    final cuentasPorId = {for (final c in cuentas) c.id: c};
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Últimos movimientos',
                  style: AppTextStyles.headlineSm,
                ),
              ),
              _EnlaceFlecha(
                texto: 'Ver historial',
                onTap: () => context.go('/movements'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final t in transacciones.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MovimientoTile(
                transaccion: t,
                nombreCuenta: cuentasPorId[t.cuentaId]?.nombre ?? '—',
                nombreContraparte: cuentasPorId[t.cuentaContraparteId]?.nombre,
              ),
            ),
        ],
      ),
    );
  }
}

class _EnlaceFlecha extends StatelessWidget {
  const _EnlaceFlecha({required this.texto, required this.onTap});

  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texto,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.acento,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.acento),
        ],
      ),
    );
  }
}

class _AvisoSinCuentas extends StatelessWidget {
  const _AvisoSinCuentas();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: AppColors.secundario.withValues(alpha: 0.12),
      borderRadius: 24,
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.secundarioClaro,
            size: 32,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              'Aún no tienes cuentas — agrega una para empezar a ver tu '
              'patrimonio y tus gastos aquí.',
              style: AppTextStyles.bodyLg,
            ),
          ),
          const SizedBox(width: 18),
          // --- Botón "Agregar cuenta" → pestaña Cuentas ---
          GradientButton(
            label: 'Agregar cuenta',
            expand: false,
            onPressed: () => context.go('/accounts'),
          ),
        ],
      ),
    );
  }
}
