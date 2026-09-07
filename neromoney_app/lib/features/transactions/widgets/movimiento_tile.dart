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
  const MovimientoTile({super.key, required this.transaccion, required this.nombreCuenta});

  final Transaccion transaccion;
  final String nombreCuenta;

  @override
  Widget build(BuildContext context) {
    final esIngreso = transaccion.tipo == TipoTransaccion.ingreso;
    final color = esIngreso ? AppColors.inflowEmerald : AppColors.textPrimary;
    final signo = esIngreso ? '+' : '-';

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
            child: Icon(iconoParaCategoria(transaccion.categoria),
                color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaccion.descripcion.isEmpty ? transaccion.categoria : transaccion.descripcion,
                  style: AppTextStyles.bodyLg,
                ),
                Text(
                  '${transaccion.fecha.day}/${transaccion.fecha.month} · $nombreCuenta',
                  style: AppTextStyles.labelCode,
                ),
              ],
            ),
          ),
          Text(
            '$signo\$${transaccion.monto.toStringAsFixed(2)}',
            style: AppTextStyles.bodyLg.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
