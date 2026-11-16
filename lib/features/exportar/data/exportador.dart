import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/fecha_es.dart';
import '../../../core/utils/formato_monto.dart';
import '../../transactions/data/resumen_gastos.dart';
import '../../transactions/data/transaccion.dart';

/// Un movimiento listo para exportar (con el nombre y la moneda de su
/// cuenta ya resueltos).
class FilaExportable {
  const FilaExportable(this.transaccion, this.cuenta, this.moneda);

  final Transaccion transaccion;
  final String cuenta;
  final String moneda;
}

String _dosDigitos(int n) => n.toString().padLeft(2, '0');
String _fechaIso(DateTime f) =>
    '${f.year}-${_dosDigitos(f.month)}-${_dosDigitos(f.day)}';

/// CSV para Excel / Google Sheets. Lleva BOM UTF-8 para que Excel muestre
/// bien los acentos, y los gastos con signo negativo para poder sumar la
/// columna directamente.
Uint8List generarCsv(List<FilaExportable> filas) {
  String celda(String v) {
    final necesita = v.contains(RegExp(r'[",\n\r]'));
    final limpio = v.replaceAll('"', '""');
    // Evita que Excel interprete un texto como fórmula (=, +, -, @).
    final seguro = RegExp(r'^[=+\-@]').hasMatch(limpio) ? "'$limpio" : limpio;
    return necesita ? '"$seguro"' : seguro;
  }

  final b = StringBuffer()
    ..write('﻿')
    ..writeln('Fecha,Tipo,Categoría,Descripción,Cuenta,Monto,Moneda');
  for (final f in filas) {
    final t = f.transaccion;
    final tipo = t.esTransferencia
        ? 'Transferencia'
        : t.tipo == TipoTransaccion.gasto
        ? 'Gasto'
        : 'Ingreso';
    final monto = t.tipo == TipoTransaccion.gasto ? -t.monto : t.monto;
    b.writeln(
      [
        _fechaIso(t.fecha),
        tipo,
        celda(t.categoria),
        celda(t.descripcion),
        celda(f.cuenta),
        monto.toStringAsFixed(2),
        f.moneda,
      ].join(','),
    );
  }
  return Uint8List.fromList(utf8.encode(b.toString()));
}

/// Las fuentes integradas del PDF solo traen Latin-1 (sí acentos y ñ, no
/// emojis ni guiones largos): lo demás se cambia por algo parecido.
String _latin1(String s) => s
    .replaceAll('—', '-')
    .replaceAll('–', '-')
    .replaceAll('•', '-')
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('’', "'")
    .replaceAll(RegExp(r'[^\u0000-ÿ]'), '');

/// Reporte en PDF (Pro): totales del periodo, gasto por categoría y la
/// lista de movimientos.
Future<Uint8List> generarPdf({
  required List<FilaExportable> filas,
  required String titulo,
  required String monedaPrincipal,
  required DateTime desde,
  required DateTime hasta,
  // Outfit (assets/fonts): con ella se ven acentos y ñ. Sin fuentes se
  // usa Helvetica, que solo trae ASCII básico.
  pw.Font? fuente,
  pw.Font? fuenteNegrita,
}) async {
  final transacciones = [for (final f in filas) f.transaccion];
  final gastos = ResumenGastos.calcular(
    transacciones,
    desde: desde,
    hasta: hasta,
  );
  final ingresos = transacciones
      .where((t) => !t.esTransferencia && t.tipo == TipoTransaccion.ingreso)
      .fold<double>(0, (a, t) => a + t.montoPrincipal);
  final acento = PdfColor.fromHex('#0E7490');
  final gris = PdfColor.fromHex('#6B7280');

  pw.Widget dato(String etiqueta, String valor, [PdfColor? color]) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB')),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(etiqueta, style: pw.TextStyle(fontSize: 9, color: gris)),
              pw.SizedBox(height: 4),
              pw.Text(
                valor,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );

  final doc = pw.Document(title: _latin1(titulo), author: 'NeroMoney');
  doc.addPage(
    pw.MultiPage(
      theme: fuente == null
          ? null
          : pw.ThemeData.withFont(base: fuente, bold: fuenteNegrita ?? fuente),
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(36),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'NeroMoney - página ${c.pageNumber} de ${c.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: gris),
        ),
      ),
      build: (c) => [
        pw.Text(
          'NeroMoney',
          style: pw.TextStyle(
            color: acento,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          _latin1(titulo),
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Montos en $monedaPrincipal. Generado el '
          '${DateTime.now().day} de ${mesesEs[DateTime.now().month - 1]} '
          'de ${DateTime.now().year}.',
          style: pw.TextStyle(fontSize: 9, color: gris),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            dato('Gastos', formatoMonto(gastos.total), PdfColors.red700),
            pw.SizedBox(width: 10),
            dato('Ingresos', formatoMonto(ingresos), PdfColors.green700),
            pw.SizedBox(width: 10),
            dato(
              'Balance',
              '${ingresos < gastos.total ? '-' : ''}'
                  '${formatoMonto((ingresos - gastos.total).abs())}',
            ),
          ],
        ),
        if (gastos.porCategoria.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          pw.Text(
            'Gasto por categoría',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Categoría', 'Monto', '%'],
            data: [
              for (final e in gastos.porCategoria.entries)
                [
                  _latin1(e.key),
                  formatoMonto(e.value),
                  '${(e.value / gastos.total * 100).round()}%',
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 10,
            ),
            headerDecoration: pw.BoxDecoration(color: acento),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
          ),
        ],
        pw.SizedBox(height: 18),
        pw.Text(
          'Movimientos (${filas.length})',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Fecha', 'Descripción', 'Categoría', 'Cuenta', 'Monto'],
          data: [
            for (final f in filas)
              [
                _fechaIso(f.transaccion.fecha),
                _latin1(f.transaccion.descripcion),
                _latin1(f.transaccion.categoria),
                _latin1(f.cuenta),
                '${f.transaccion.tipo == TipoTransaccion.gasto ? '-' : '+'}'
                    '${formatoMonto(f.transaccion.monto)}'
                    '${f.moneda == monedaPrincipal ? '' : ' ${f.moneda}'}',
              ],
          ],
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 9,
          ),
          headerDecoration: pw.BoxDecoration(color: acento),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          cellAlignments: {4: pw.Alignment.centerRight},
          columnWidths: {
            0: const pw.FixedColumnWidth(62),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FixedColumnWidth(80),
          },
        ),
      ],
    ),
  );
  return doc.save();
}
