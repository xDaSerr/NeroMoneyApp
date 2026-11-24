import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formato_monto.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/apunte_libreta.dart';
import '../providers/libreta_providers.dart';

/// En Inicio, solo si hay préstamos sin pagar: cuánto te deben, cuánto
/// debes y si alguno ya pasó su fecha. Toca para abrir la Libreta.
class TarjetaLibretaInicio extends ConsumerWidget {
  const TarjetaLibretaInicio({
    super.key,
    this.padding = const EdgeInsets.all(18),
    this.radio = 22,
    this.margenArriba = 14,
  });

  final EdgeInsetsGeometry padding;
  final double radio;
  final double margenArriba;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apuntes = ref.watch(apuntesLibretaProvider).value;
    if (apuntes == null) return const SizedBox.shrink();
    final r = ResumenLibreta.calcular(apuntes, DateTime.now());
    if (r.meDeben <= 0 && r.debo <= 0) return const SizedBox.shrink();

    final partes = [
      if (r.meDeben > 0) 'Te deben ${formatoMonto(r.meDeben)}',
      if (r.debo > 0) 'Debes ${formatoMonto(r.debo)}',
    ];
    return Padding(
      padding: EdgeInsets.only(top: margenArriba),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.push('/libreta'),
          child: GlassCard(
            borderRadius: radio,
            padding: padding,
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.acento,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Libreta', style: AppTextStyles.headlineSm),
                      Text(
                        partes.join(' · '),
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (r.vencidos > 0)
                        Text(
                          r.vencidos == 1
                              ? '1 préstamo ya pasó su fecha de pago'
                              : '${r.vencidos} préstamos ya pasaron su fecha de pago',
                          style: AppTextStyles.bodyMd.copyWith(
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.acento),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
