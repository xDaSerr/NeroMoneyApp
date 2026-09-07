import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';

/// Dona de categorías (sigue `12._reportes_y_estad_sticas` del Stitch): un
/// arco de grosor fijo por categoría, proporcional a su parte del total, con
/// el total en el centro. Sin librería externa — un `CustomPainter` con
/// `Canvas.drawArc` es más que suficiente para esto.
class DonaCategorias extends StatelessWidget {
  const DonaCategorias({
    super.key,
    required this.entradas,
    required this.total,
    required this.colores,
    this.tamano = 148,
    this.grosor = 24,
  });

  final List<MapEntry<String, double>> entradas;
  final double total;
  final List<Color> colores;
  final double tamano;
  final double grosor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(tamano, tamano),
            painter: _DonaPainter(
              entradas: entradas,
              total: total,
              colores: colores,
              grosor: grosor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\$${total.toStringAsFixed(0)}',
                style: AppTextStyles.headlineSm,
              ),
              Text('Total', style: AppTextStyles.bodySm),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonaPainter extends CustomPainter {
  _DonaPainter({
    required this.entradas,
    required this.total,
    required this.colores,
    required this.grosor,
  });

  final List<MapEntry<String, double>> entradas;
  final double total;
  final List<Color> colores;
  final double grosor;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0.01 || entradas.isEmpty) return;
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = (size.shortestSide - grosor) / 2;
    final rect = Rect.fromCircle(center: centro, radius: radio);

    // Separación visual entre arcos, como en el mockup — proporcional al
    // radio para que no se vea desproporcionada en tamaños distintos.
    const separacionGrados = 0.05;
    var anguloInicio = -pi / 2;

    for (var i = 0; i < entradas.length; i++) {
      final proporcion = entradas[i].value / total;
      final barrido = (2 * pi * proporcion) - separacionGrados;
      if (barrido <= 0) continue;
      final pintura = Paint()
        ..color = colores[i % colores.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, anguloInicio, barrido, false, pintura);
      anguloInicio += 2 * pi * proporcion;
    }
  }

  @override
  bool shouldRepaint(covariant _DonaPainter oldDelegate) {
    return oldDelegate.total != total ||
        oldDelegate.entradas.length != entradas.length ||
        oldDelegate.colores != colores;
  }
}
