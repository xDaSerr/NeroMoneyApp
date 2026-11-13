import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'data/transaccion.dart';
import 'providers/transacciones_providers.dart';
import 'widgets/movimientos_escritorio.dart';
import 'widgets/movimientos_movil.dart';

class MovementsScreen extends StatelessWidget {
  const MovementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ventana ancha: tabla con buscador, filtros y paginación; teléfono:
    // tarjetas agrupadas por día (diseño móvil del usuario).
    return esEscritorio(context)
        ? const MovimientosEscritorio()
        : const MovimientosMovil();
  }
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

/// Confirma y elimina un movimiento (o deshace una transferencia completa).
/// Lo comparten el deslizar del teléfono y el menú "⋯" de la tabla de
/// escritorio. Devuelve true solo si de verdad se borró.
Future<bool> eliminarMovimiento(
  BuildContext context,
  WidgetRef ref,
  Transaccion t,
) async {
  final confirmado = await _confirmarEliminar(context, t);
  if (!confirmado) return false;
  try {
    await ref.read(transaccionesRepositoryProvider).eliminarTransaccion(t);
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StateError
                ? e.message
                : 'No se pudo eliminar el movimiento. Revisa tu conexión.',
          ),
        ),
      );
    }
    return false;
  }
}
