import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../account_detail_screen.dart' show heroDeCuenta;
import '../../../core/moneda/monedas_providers.dart';
import '../../../core/router/app_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/boton_con_panel.dart';
import '../../../core/widgets/piezas_movil.dart';
import '../../home/providers/privacidad_inicio_provider.dart';
import '../../onboarding/providers/perfil_providers.dart';
import '../data/cuenta.dart';
import '../providers/cuentas_providers.dart';
import 'cuenta_movil.dart';
import 'editar_cuenta_sheet.dart';
import 'panel_nueva_cuenta.dart';

/// Cuentas en teléfono (diseño móvil del usuario): patrimonio, filtros por
/// tipo y las cuentas en dos columnas, cada una con su menú "⋯". Borrar
/// sigue viviendo en el detalle de la cuenta.
class CuentasMovil extends ConsumerStatefulWidget {
  const CuentasMovil({super.key});

  @override
  ConsumerState<CuentasMovil> createState() => _CuentasMovilState();
}

class _CuentasMovilState extends ConsumerState<CuentasMovil> {
  TipoCuenta? _filtro; // null = todas

  @override
  Widget build(BuildContext context) {
    // Multimoneda: recalcular cuando cambian las cuentas o los tipos de cambio.
    ref.watch(conversorMonedaProvider);
    final cuentasAsync = ref.watch(cuentasProvider);
    final privacidad = ref.watch(privacidadInicioProvider);
    final ocultar = privacidad.value ?? true;
    final moneda = ref.watch(perfilProvider).value?.moneda ?? 'MXN';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        // Slivers: la cuadrícula solo construye las tarjetas visibles
        // (importa cuando hay decenas de cuentas).
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                18,
                14,
                18,
                20 + espacioParaBarraFlotante(context),
              ),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const EncabezadoMovil(),
                        const SizedBox(height: 18),
                        TituloMovil(
                          titulo: 'Cuentas',
                          subtitulo: 'Tus bolsillos, organizados.',
                          // --- "+ Agregar": se transforma en "Nueva cuenta" ---
                          accion: BotonConPanel(
                            tamanoPanel: const Size(900, 860),
                            colorBoton: AppColors.acento,
                            boton: (context, abrir) => BotonAccionMovil(
                              texto: 'Agregar',
                              onTap: abrir,
                            ),
                            panel: (context, cerrar) =>
                                PanelNuevaCuenta(onCerrar: cerrar),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                  ...cuentasAsync.when(
                    data: (cuentas) => _contenido(
                      cuentas,
                      ocultar,
                      privacidad.isLoading,
                      moneda,
                    ),
                    loading: () => [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.acento,
                            ),
                          ),
                        ),
                      ),
                    ],
                    error: (e, _) => [
                      SliverToBoxAdapter(
                        child: Text(
                          'No se pudieron cargar tus cuentas: $e',
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.outflowCrimson,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _contenido(
    List<Cuenta> cuentas,
    bool ocultar,
    bool cargandoPrivacidad,
    String moneda,
  ) {
    if (cuentas.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: TarjetaMovil(
            child: Text(
              'Todavía no tienes ninguna cuenta. Toca "Agregar" para crear la '
              'primera.',
              style: AppTextStyles.bodyLg,
            ),
          ),
        ),
      ];
    }
    if (_filtro != null && !cuentas.any((c) => c.tipo == _filtro)) {
      _filtro = null;
    }
    final visibles = _filtro == null
        ? cuentas
        : cuentas.where((c) => c.tipo == _filtro).toList();
    final total = cuentas.fold<double>(
      0,
      (a, c) => a + c.efectoEnPatrimonioPrincipal,
    );

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Patrimonio (sin tarjetas de crédito, ver Cuenta.efectoEnPatrimonio) ---
            TarjetaPatrimonioMovil(
              total: total,
              moneda: moneda,
              ocultar: ocultar,
              nota: 'Sin contar tarjetas de crédito',
              onAlternar: cargandoPrivacidad
                  ? null
                  : () => ref
                        .read(privacidadInicioProvider.notifier)
                        .alternar()
                        .catchError((Object _) {}),
            ),
            const SizedBox(height: 16),
            // --- Filtros por tipo (solo los tipos que sí tienes) ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Filtro(
                    texto: 'Todas (${cuentas.length})',
                    seleccionado: _filtro == null,
                    onTap: () => setState(() => _filtro = null),
                  ),
                  for (final tipo in TipoCuenta.values)
                    if (cuentas.any((c) => c.tipo == tipo)) ...[
                      const SizedBox(width: 8),
                      _Filtro(
                        texto:
                            '${tipo.etiqueta} (${cuentas.where((c) => c.tipo == tipo).length})',
                        seleccionado: _filtro == tipo,
                        onTap: () => setState(() => _filtro = tipo),
                      ),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      // --- Cuadrícula de dos columnas ---
      SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 236,
        ),
        itemCount: visibles.length,
        itemBuilder: (context, i) {
          final cuenta = visibles[i];
          return InkWell(
                key: ValueKey(cuenta.id),
                borderRadius: BorderRadius.circular(20),
                onTap: () =>
                    context.push('/accounts/detalle', extra: cuenta.id),
                // La tarjeta "vuela" hasta el detalle de la cuenta.
                child: Hero(
                  tag: heroDeCuenta(cuenta.id),
                  flightShuttleBuilder: (_, _, _, _, destino) => Material(
                    type: MaterialType.transparency,
                    child: destino.widget,
                  ),
                  child: CuentaMovil(
                    cuenta: cuenta,
                    ocultar: ocultar,
                    enCuadricula: true,
                    accion: _menu(cuenta),
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: (50 * i.clamp(0, 6)).ms, duration: 280.ms)
              .scale(
                begin: const Offset(0.97, 0.97),
                duration: 280.ms,
                curve: Curves.easeOutCubic,
              );
        },
      ),
      // --- Transferir entre cuentas ---
      if (cuentas.length > 1)
        SliverPadding(
          padding: const EdgeInsets.only(top: 16),
          sliver: SliverToBoxAdapter(
            child: OutlinedButton.icon(
              onPressed: () => context.push('/transfer'),
              icon: Icon(Icons.swap_horiz_rounded, color: AppColors.acento),
              label: Text(
                'Transferir entre cuentas',
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: AppColors.acento.withValues(alpha: 0.7),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  /// "⋯" de cada tarjeta: ver detalle o editar.
  Widget _menu(Cuenta cuenta) {
    return SizedBox(
      width: 36,
      height: 36,
      child: PopupMenuButton<void>(
        tooltip: 'Opciones',
        padding: EdgeInsets.zero,
        color: AppColors.surface1,
        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
        itemBuilder: (_) => [
          PopupMenuItem(
            onTap: () => context.push('/accounts/detalle', extra: cuenta.id),
            child: const Text('Ver detalle y movimientos'),
          ),
          PopupMenuItem(
            onTap: () => mostrarEditorDeCuenta(
              context: context,
              cuenta: cuenta,
              onGuardar: (actualizada) => ref
                  .read(cuentasRepositoryProvider)
                  .actualizarCuenta(actualizada),
            ),
            child: const Text('Editar'),
          ),
        ],
      ),
    );
  }
}

class _Filtro extends StatelessWidget {
  const _Filtro({
    required this.texto,
    required this.seleccionado,
    required this.onTap,
  });

  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColors.acento.withValues(alpha: 0.14)
              : AppColors.surface2Glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: seleccionado
                ? AppColors.acento.withValues(alpha: 0.6)
                : AppColors.glassStrokeStandard,
          ),
        ),
        child: Text(
          texto,
          style: AppTextStyles.bodyLg.copyWith(
            color: seleccionado ? AppColors.acento : AppColors.textSecondary,
            fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
