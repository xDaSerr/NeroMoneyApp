import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../accounts/data/cuenta.dart';
import '../accounts/providers/cuentas_providers.dart';
import 'data/transaccion.dart';
import 'providers/transacciones_providers.dart';
import 'widgets/movimiento_tile.dart';

class MovementsScreen extends ConsumerWidget {
  const MovementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaccionesAsync = ref.watch(transaccionesProvider);
    final cuentasAsync = ref.watch(cuentasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      // --- Botón flotante "+": abre la pantalla de alta manual (add_transaction_screen.dart) ---
      // Envuelto en Padding (en vez de solo el FAB) para subirlo por
      // encima de la píldora flotante de navegación (ver AppShell,
      // extendBody:true) — si no, quedaría tapado detrás de ella.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: espacioParaBarraFlotante(context)),
        child: FloatingActionButton(
          backgroundColor: AppColors.primaryCyan,
          foregroundColor: AppColors.canvas,
          onPressed: () => context.push('/add-transaction'),
          child: const Icon(Icons.add_rounded),
        ),
      ),
      body: transaccionesAsync.when(
        data: (transacciones) {
          if (transacciones.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Aún no tienes movimientos. Toca "+" para registrar el primero.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMd,
                ),
              ),
            );
          }
          final cuentas = cuentasAsync.value ?? const <Cuenta>[];
          final cuentasPorId = {for (final c in cuentas) c.id: c};
          return ListView.separated(
            // El extra abajo es para que la píldora flotante de navegación
            // (ver AppShell, extendBody:true) nunca tape el último
            // movimiento de la lista.
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + espacioParaBarraFlotante(context),
            ),
            itemCount: transacciones.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final t = transacciones[i];
              final nombreCuenta = cuentasPorId[t.cuentaId]?.nombre ?? '—';
              // --- Deslizar hacia la izquierda para eliminar un movimiento ---
              // (revierte también su efecto en el saldo de la cuenta, ver
              // TransaccionesRepository.eliminarTransaccion).
              return Dismissible(
                key: ValueKey(t.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.outflowCrimson.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                  ),
                ),
                // El borrado real se hace AQUÍ (no en onDismissed): si se
                // hace después de que la animación ya quitó el widget de la
                // pantalla, Firestore tarda un poco en confirmar y Flutter
                // se queja de que "un Dismissible ya descartado sigue en el
                // árbol". Al esperar el borrado antes de devolver `true`,
                // el widget solo desaparece cuando el dato ya se borró de verdad.
                confirmDismiss: (_) async {
                  final confirmado = await _confirmarEliminar(context, t);
                  if (!confirmado) return false;
                  try {
                    await ref
                        .read(transaccionesRepositoryProvider)
                        .eliminarTransaccion(t);
                    return true;
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e is StateError ? e.message : 'No se pudo eliminar el movimiento. Revisa tu conexión.',
                          ),
                        ),
                      );
                    }
                    return false;
                  }
                },
                child: MovimientoTile(
                  transaccion: t,
                  nombreCuenta: nombreCuenta,
                  nombreContraparte:
                      cuentasPorId[t.cuentaContraparteId]?.nombre,
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryCyan),
        ),
        error: (e, _) => Center(
          child: Text(
            'No se pudieron cargar tus movimientos: $e',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.outflowCrimson,
            ),
          ),
        ),
      ),
    );
  }

  // Eliminar un movimiento revierte su efecto en el saldo — mejor confirmar
  // antes de aplicar un swipe accidental que borre datos reales.
  Future<bool> _confirmarEliminar(BuildContext context, Transaccion t) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text(
          t.esTransferencia
              ? '¿Deshacer esta transferencia?'
              : '¿Eliminar este movimiento?',
        ),
        content: Text(
          '${t.descripcion.isEmpty ? t.categoria : t.descripcion} — \$${t.monto.toStringAsFixed(2)}.\n'
          '${t.esTransferencia ? 'Se eliminarán la salida y la entrada, y el dinero volverá a la cuenta de origen en tus registros.' : 'Esto también revierte su efecto en el saldo de la cuenta.'}',
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
    return confirmado ?? false;
  }
}
