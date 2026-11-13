import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/periodo_reporte.dart';

/// Gráfica de barras con ejes para Reportes en escritorio: montos en el eje
/// vertical, líneas guía punteadas y una barra de ingreso y otra de gasto
/// por tramo. Dibujada a mano (CustomPainter), sin librería de gráficas.
class GraficaFlujo extends StatelessWidget {
  const GraficaFlujo({super.key, required this.buckets, this.altura = 260});

  final List<BucketFlujo> buckets;
  final double altura;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: altura,
      width: double.infinity,
      child: CustomPaint(
        painter: _PintorFlujo(
          buckets: buckets,
          estiloEje: AppTextStyles.labelCode.copyWith(fontSize: 12),
          estiloTramo: AppTextStyles.bodyMd,
          colorGuia: AppColors.glassStrokeHighlight,
          colorEje: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _PintorFlujo extends CustomPainter {
  _PintorFlujo({
    required this.buckets,
    required this.estiloEje,
    required this.estiloTramo,
    required this.colorGuia,
    required this.colorEje,
  });

  final List<BucketFlujo> buckets;
  final TextStyle estiloEje;
  final TextStyle estiloTramo;
  final Color colorGuia;
  final Color colorEje;

  static final _formato = NumberFormat('#,##0', 'en_US');

  /// Redondea hacia arriba a un número "bonito" (1, 2, 2.5 o 5 × 10ⁿ) para
  /// que el eje tenga marcas legibles.
  static double _techo(double valor) {
    if (valor <= 0) return 100;
    final potencia = math.pow(10, (math.log(valor) / math.ln10).floor());
    for (final f in [1, 2, 2.5, 5, 10]) {
      if (f * potencia >= valor) return (f * potencia).toDouble();
    }
    return valor;
  }

  TextPainter _texto(String texto, TextStyle estilo) => TextPainter(
    text: TextSpan(text: texto, style: estilo),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final maximo = buckets.fold<double>(
      0,
      (a, b) => math.max(a, math.max(b.ingreso, b.gasto)),
    );
    final techo = _techo(maximo);
    const marcas = 4;
    final anchoEje =
        _texto('\$${_formato.format(techo)}', estiloEje).width + 14;
    const altoTramos = 30.0;
    final area = Rect.fromLTRB(
      anchoEje,
      8,
      size.width,
      size.height - altoTramos,
    );

    // Líneas guía punteadas + montos del eje.
    final guia = Paint()
      ..color = colorGuia
      ..strokeWidth = 1;
    for (var i = 0; i <= marcas; i++) {
      final y = area.bottom - area.height * i / marcas;
      final valor = techo * i / marcas;
      final etiqueta = _texto('\$${_formato.format(valor)}', estiloEje);
      etiqueta.paint(
        canvas,
        Offset(anchoEje - etiqueta.width - 10, y - etiqueta.height / 2),
      );
      if (i == 0) continue;
      for (var x = area.left; x < area.right; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, area.right), y),
          guia,
        );
      }
    }
    // Ejes.
    final eje = Paint()
      ..color = colorEje.withValues(alpha: 0.6)
      ..strokeWidth = 1.2;
    canvas.drawLine(area.bottomLeft, area.bottomRight, eje);
    canvas.drawLine(area.bottomLeft, area.topLeft, eje);

    if (buckets.isEmpty) return;
    final anchoTramo = area.width / buckets.length;
    final anchoBarra = math.min(34.0, anchoTramo * 0.3);
    for (final (i, b) in buckets.indexed) {
      final centro = area.left + anchoTramo * (i + 0.5);
      void barra(double valor, double x, Color color) {
        if (valor <= 0) return;
        final alto = area.height * (valor / techo);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, area.bottom - alto, anchoBarra, alto),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = color,
        );
      }

      barra(b.ingreso, centro - anchoBarra - 2, AppColors.inflowEmerald);
      barra(b.gasto, centro + 2, AppColors.outflowCrimson);
      final etiqueta = _texto(b.etiqueta, estiloTramo);
      etiqueta.paint(
        canvas,
        Offset(centro - etiqueta.width / 2, area.bottom + 8),
      );
    }
  }

  @override
  bool shouldRepaint(_PintorFlujo viejo) =>
      viejo.buckets != buckets || viejo.colorGuia != colorGuia;
}
