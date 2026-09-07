import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import 'data/cuenta.dart';
import 'providers/cuentas_providers.dart';
import 'widgets/cuenta_form_card.dart';
import 'widgets/cuenta_tile.dart';

/// Pestaña "Cuentas" — sigue `14._cuentas_y_tarjetas_vinculadas` del Stitch
/// (chips de filtro por tipo, tarjetas visuales), pero solo con lo real:
/// sin "Open Banking sincronizado" ni el widget de auditoría de Lucy (esas
/// funciones no existen, ver CLAUDE.md → regla de fidelidad al Stitch).
/// Tocar una cuenta lleva al detalle (editar, ver sus movimientos, borrar).
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  // null = "Todas". Se resetea solo si el filtro elegido se queda sin
  // cuentas (ej. borraste la única tarjeta de crédito que tenías).
  TipoCuenta? _filtro;

  @override
  Widget build(BuildContext context) {
    final cuentasAsync = ref.watch(cuentasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas')),
      body: cuentasAsync.when(
        data: (cuentas) {
          if (_filtro != null && !cuentas.any((c) => c.tipo == _filtro)) {
            _filtro = null;
          }
          final visibles = _filtro == null ? cuentas : cuentas.where((c) => c.tipo == _filtro).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cuentas.isNotEmpty) ...[
                  // --- Chips de filtro por tipo (solo los tipos que sí tienes) ---
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ChipFiltro(
                          label: 'Todas (${cuentas.length})',
                          seleccionado: _filtro == null,
                          onTap: () => setState(() => _filtro = null),
                        ),
                        for (final tipo in TipoCuenta.values)
                          if (cuentas.any((c) => c.tipo == tipo)) ...[
                            const SizedBox(width: 8),
                            _ChipFiltro(
                              label:
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
                // --- Lista de cuentas (toca una para ver detalle/editar/borrar) ---
                if (cuentas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Todavía no tienes ninguna cuenta agregada.',
                      style: AppTextStyles.bodyMd,
                    ),
                  )
                else
                  for (final cuenta in visibles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push('/accounts/detalle', extra: cuenta.id),
                        child: CuentaTile(cuenta: cuenta),
                      ),
                    ),
                const SizedBox(height: 12),
                // --- Tarjeta con el formulario para agregar una cuenta nueva ---
                // (el formulario en sí, incluido su botón "Agregar cuenta", vive en
                // widgets/cuenta_form_card.dart)
                GlassCard(
                  child: CuentaFormCard(
                    onAgregar: (cuenta) => ref.read(cuentasRepositoryProvider).crearCuenta(cuenta),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan)),
        error: (e, _) => Center(
          child: Text('No se pudieron cargar tus cuentas: $e',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.outflowCrimson)),
        ),
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({required this.label, required this.seleccionado, required this.onTap});
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
