import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/periodo_reporte.dart';

/// Gráfico de barras "Ingresos vs Gastos" por tramo (día/semana/mes según el
/// periodo elegido, ver `calcularBuckets`). Sin librería externa — son solo
/// contenedores con alto proporcional al máximo del conjunto, mismo criterio
/// visual que la barra apilada de "Gastos del mes" en Inicio.
class BarrasFlujo extends StatelessWidget {
  const BarrasFlujo({super.key, required this.buckets, this.altura = 120});

  final List<BucketFlujo> buckets;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final maximo = buckets.fold<double>(
      0,
      (acc, b) => [acc, b.ingreso, b.gasto].reduce((a, c) => a > c ? a : c),
    );

    return SizedBox(
      height: altura + 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in buckets)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Barra(
                          alto: maximo <= 0 ? 0 : altura * (b.ingreso / maximo),
                          color: AppColors.inflowEmerald,
                        ),
                        const SizedBox(width: 3),
                        _Barra(
                          alto: maximo <= 0 ? 0 : altura * (b.gasto / maximo),
                          color: AppColors.outflowCrimson,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      b.etiqueta,
                      style: AppTextStyles.labelCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({required this.alto, required this.color});
  final double alto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Mínimo de 2px: para que un tramo en $0 siga marcando su lugar en el
    // eje en vez de desaparecer del todo (se vería como un hueco raro).
    return Container(
      width: 8,
      height: alto.clamp(2, double.infinity),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// Leyenda "● Ingresos ● Gastos" para acompañar el gráfico de barras.
class LeyendaFlujo extends StatelessWidget {
  const LeyendaFlujo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Punto(color: AppColors.inflowEmerald),
        const SizedBox(width: 6),
        Text('Ingresos', style: AppTextStyles.bodySm),
        const SizedBox(width: 16),
        _Punto(color: AppColors.outflowCrimson),
        const SizedBox(width: 6),
        Text('Gastos', style: AppTextStyles.bodySm),
      ],
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
