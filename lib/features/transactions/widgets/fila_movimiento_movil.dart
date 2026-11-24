import 'package:flutter/material.dart';

import '../../../core/moneda/conversor_moneda.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/piezas_escritorio.dart' show colorDeCategoria;
import '../data/categoria.dart';
import '../data/transaccion.dart';

/// Una fila de movimiento del diseño móvil (Inicio y Movimientos): ícono de
/// la categoría en su color, concepto, detalle debajo y el monto en verde
/// (ingreso) o rojo (gasto). Va dentro de una tarjeta que agrupa varias.
class FilaMovimientoMovil extends StatelessWidget {
  const FilaMovimientoMovil({
    super.key,
    required this.transaccion,
    required this.detalle,
  });

  final Transaccion transaccion;

  /// "Compras • Efectivo" o "10 nov • Efectivo".
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final t = transaccion;
    final esIngreso = t.tipo == TipoTransaccion.ingreso;
    final color = t.esTransferencia
        ? AppColors.acento
        : colorDeCategoria(t.categoria, esIngreso: esIngreso);
    final concepto = t.esTransferencia
        ? 'Transferencia'
        : (t.descripcion.isEmpty ? t.categoria : t.descripcion);
    final colorMonto = t.esTransferencia
        ? AppColors.acento
        : (esIngreso ? AppColors.inflowEmerald : AppColors.outflowCrimson);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(
              t.esTransferencia
                  ? Icons.swap_horiz_rounded
                  : iconoParaCategoria(t.categoria),
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concepto,
                  style: AppTextStyles.bodyLg.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  t.horaVisible == null ? detalle : '$detalle · ${t.horaVisible}',
                  style: AppTextStyles.bodyMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${esIngreso ? '+' : '−'}${ConversorMoneda.formato(t.monto, t.cuentaId)}',
            style: AppTextStyles.bodyLg.copyWith(
              color: colorMonto,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}
