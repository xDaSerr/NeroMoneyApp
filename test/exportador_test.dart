import 'dart:convert';
import 'dart:io';

import 'package:pdf/widgets.dart' as pw;

import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/core/moneda/conversor_moneda.dart';
import 'package:neromoney_app/features/exportar/data/exportador.dart';
import 'package:neromoney_app/features/transactions/data/transaccion.dart';

Transaccion _t(
  double monto,
  TipoTransaccion tipo,
  String categoria,
  String descripcion,
  DateTime fecha, {
  String cuenta = 'c1',
}) => Transaccion(
  id: '$monto$descripcion',
  monto: monto,
  tipo: tipo,
  categoria: categoria,
  cuentaId: cuenta,
  fecha: fecha,
  descripcion: descripcion,
);

void main() {
  tearDown(ConversorMoneda.reiniciar);

  final filas = [
    FilaExportable(
      _t(
        250.5,
        TipoTransaccion.gasto,
        'Alimentación',
        'Café, "el bueno"',
        DateTime(2026, 11, 3),
      ),
      'Efectivo',
      'MXN',
    ),
    FilaExportable(
      _t(
        9000,
        TipoTransaccion.ingreso,
        'Nómina',
        '=HYPERLINK("x")',
        DateTime(2026, 11, 1),
      ),
      'Nu',
      'MXN',
    ),
  ];

  test('CSV: BOM, encabezados, comillas, signos y sin fórmulas', () {
    final bytes = generarCsv(filas);
    // BOM UTF-8 (EF BB BF): Excel lo necesita para leer bien los acentos.
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    final texto = utf8.decode(bytes);
    final lineas = texto.trim().split('\n');
    expect(
      lineas[0].replaceAll('﻿', ''),
      'Fecha,Tipo,Categoría,Descripción,Cuenta,Monto,Moneda',
    );
    expect(
      lineas[1],
      '2026-11-03,Gasto,Alimentación,"Café, ""el bueno""",Efectivo,-250.50,MXN',
    );
    // El texto que empieza con "=" se neutraliza para que Excel no lo
    // ejecute como fórmula.
    expect(lineas[2], contains('"\'=HYPERLINK(""x"")"'));
    expect(lineas[2], endsWith(',9000.00,MXN'));
  });

  test('PDF: se genera un archivo PDF válido', () async {
    final bytes = await generarPdf(
      filas: filas,
      titulo: 'Movimientos: Este mes — prueba 🎉',
      monedaPrincipal: 'MXN',
      desde: DateTime(2026, 11),
      hasta: DateTime(2026, 12),
      fuente: pw.Font.ttf(
        File('assets/fonts/Outfit-Regular.ttf')
            .readAsBytesSync()
            .buffer
            .asByteData(),
      ),
      fuenteNegrita: pw.Font.ttf(
        File('assets/fonts/Outfit-Bold.ttf')
            .readAsBytesSync()
            .buffer
            .asByteData(),
      ),
    );
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('multimoneda: los totales convierten, cada fila conserva su moneda', () {
    ConversorMoneda.configurar(
      principal: 'MXN',
      monedaPorCuenta: {'usd': 'USD'},
      tasas: {'USD': 1, 'MXN': 18},
    );
    final t = _t(
      10,
      TipoTransaccion.gasto,
      'Ocio',
      'Netflix',
      DateTime(2026, 11, 5),
      cuenta: 'usd',
    );
    expect(t.montoPrincipal, 180);
    expect(ConversorMoneda.formato(10, 'usd'), r'$10.00 USD');
    expect(ConversorMoneda.formato(10, 'c1'), r'$10.00');
    // Sin tasas no inventa conversiones.
    ConversorMoneda.configurar(
      principal: 'MXN',
      monedaPorCuenta: {'usd': 'USD'},
      tasas: const {},
    );
    expect(t.montoPrincipal, 10);
  });
}
