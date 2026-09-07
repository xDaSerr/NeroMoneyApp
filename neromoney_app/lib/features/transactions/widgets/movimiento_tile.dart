import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/categoria.dart';
import '../data/transaccion.dart';

/// Fila que representa un movimiento (gasto o ingreso), usada tanto en
/// Movimientos como en la vista previa de Inicio — un solo lugar para no
/// duplicar esta lógica en dos pantallas (mismo patrón que CuentaTile).
class MovimientoTile extends StatelessWidget {
  const MovimientoTile({
    super.key,
    required this.transaccion,
    required this.nombreCuenta,
    this.nombreContraparte,
  });

  final Transaccion transaccion;
  final String nombreCuenta;
  final String? nombreContraparte;

  @override
  Widget build(BuildContext context) {
    final esIngreso = transaccion.tipo == TipoTransaccion.ingreso;
    final color = transaccion.esTransferencia
        ? AppColors.primaryCyan
        : (esIngreso ? AppColors.inflowEmerald : AppColors.textPrimary);
    final signo = esIngreso ? '+' : '-';
    final recorrido = esIngreso
        ? '${nombreContraparte ?? 'Cuenta eliminada'} → $nombreCuenta'
        : '$nombreCuenta → ${nombreContraparte ?? 'Cuenta eliminada'}';

    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface3ActiveGlass,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              transaccion.esTransferencia
                  ? Icons.swap_horiz_rounded
                  : iconoParaCategoria(transaccion.categoria),
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (transaccion.esTransferencia)
                  Text(
                    esIngreso
                        ? 'Transferencia recibida'
                        : 'Transferencia enviada',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.primaryCyan,
                    ),
                  ),
                Text(
                  transaccion.esTransferencia && transaccion.descripcion.isEmpty
                      ? recorrido
                      : (transaccion.descripcion.isEmpty
                            ? transaccion.categoria
                            : transaccion.descripcion),
                  style: AppTextStyles.bodyLg,
                ),
                Text(
                  '${transaccion.fecha.day}/${transaccion.fecha.month} · ${transaccion.esTransferencia && transaccion.descripcion.isNotEmpty ? recorrido : nombreCuenta}',
                  style: AppTextStyles.labelCode,
                ),
              ],
            ),
          ),
          Text(
            '$signo\$${transaccion.monto.toStringAsFixed(2)}',
            style: AppTextStyles.bodyLg.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
