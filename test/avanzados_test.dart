import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/features/reports/data/avanzados.dart';
import 'package:neromoney_app/features/reports/data/periodo_reporte.dart';
import 'package:neromoney_app/features/transactions/data/transaccion.dart';

var _n = 0;
Transaccion _t(
  double monto,
  String categoria,
  DateTime fecha, {
  TipoTransaccion tipo = TipoTransaccion.gasto,
}) => Transaccion(
  id: '${_n++}',
  monto: monto,
  tipo: tipo,
  categoria: categoria,
  cuentaId: 'c',
  fecha: fecha,
);

void main() {
  test('comparación por categoría y total', () {
    final actual = RangoPeriodo(
      desde: DateTime(2026, 11),
      hasta: DateTime(2026, 12),
      etiqueta: 'Noviembre 2026',
      esActual: false,
    );
    final anterior = RangoPeriodo(
      desde: DateTime(2026, 10),
      hasta: DateTime(2026, 11),
      etiqueta: 'Octubre 2026',
      esActual: false,
    );
    final c = Comparacion.calcular(
      [
        _t(1000, 'Alimentación', DateTime(2026, 11, 3)),
        _t(500, 'Ocio', DateTime(2026, 11, 4)),
        _t(800, 'Alimentación', DateTime(2026, 10, 3)),
        _t(1000, 'Ocio', DateTime(2026, 10, 4)),
        _t(300, 'Salud', DateTime(2026, 10, 9)),
      ],
      actual,
      anterior,
    );
    expect(c.totalActual, 1500);
    expect(c.totalAnterior, 2100);
    expect(c.cambio, closeTo(-0.2857, 0.001));
    expect(c.categorias.map((x) => x.categoria), [
      'Alimentación',
      'Ocio',
      'Salud',
    ]);
    expect(c.categorias[0].cambio, closeTo(0.25, 0.001));
    expect(c.categorias[1].cambio, -0.5);
    expect(c.categorias[2].actual, 0);
    expect(c.etiquetaAnterior, 'Octubre 2026');
  });

  test('el mes en curso se compara contra el anterior al mismo día', () {
    final ahora = DateTime(2026, 11, 13, 12);
    final r = Comparacion.rangoAnterior(
      const SeleccionPeriodo(TipoPeriodo.mes),
      ahora,
    );
    // calcularRangoPeriodo usa la fecha real: solo se revisa la forma.
    expect(r.desde.day, 1);
    expect(r.hasta.isAfter(r.desde), isTrue);
    expect(r.esActual, isFalse);
  });

  test('tendencia: 12 meses con gasto neto e ingreso', () {
    final ahora = DateTime(2026, 11, 13);
    final datos = tendenciaDoceMeses([
      _t(400, 'Ocio', DateTime(2026, 11, 2)),
      _t(100, 'Ocio', DateTime(2026, 11, 3), tipo: TipoTransaccion.ingreso),
      _t(9000, 'Nómina', DateTime(2026, 11, 1), tipo: TipoTransaccion.ingreso),
      _t(700, 'Salud', DateTime(2025, 12, 10)),
      _t(999, 'Salud', DateTime(2025, 11, 10)), // fuera de la ventana
    ], ahora);
    expect(datos, hasLength(12));
    expect(datos.first.etiqueta, 'Dic');
    expect(datos.first.gasto, 700);
    expect(datos.last.etiqueta, 'Nov');
    expect(datos.last.gasto, 300);
    expect(datos.last.ingreso, 9100);
  });

  test('resumen del año y proyección a diciembre', () {
    final ahora = DateTime(2026, 4, 15); // 3.5 meses transcurridos
    final r = ResumenAnio.calcular([
      _t(7000, 'Vivienda', DateTime(2026, 1, 5)),
      _t(1000, 'Ocio', DateTime(2026, 2, 5)),
      _t(2000, 'Ocio', DateTime(2026, 3, 5)),
      _t(14000, 'Nómina', DateTime(2026, 1, 1), tipo: TipoTransaccion.ingreso),
      _t(9999, 'Ocio', DateTime(2025, 12, 31)), // otro año
    ], ahora);
    expect(r.gasto, 10000);
    expect(r.ingreso, 14000);
    expect(r.ahorro, 4000);
    expect(r.mesesTranscurridos, 3.5);
    expect(r.mesMasCaro, 1);
    expect(r.categoriaPrincipal, 'Vivienda');
    // Usa la app desde enero: el ritmo se mide sobre los 3.5 meses.
    expect(r.mesesActivos, closeTo(3.5, 0.05));
    expect(r.proyeccionGasto, closeTo(10000 / 3.5 * 12, 50));
    expect(r.proyeccionAhorro, closeTo(4000 / 3.5 * 12, 50));
  });

  test('si empezó a usar la app tarde, el ritmo cuenta desde ahí', () {
    final ahora = DateTime(2026, 11, 13);
    final r = ResumenAnio.calcular([
      _t(1000, 'Compras', DateTime(2026, 11, 2)),
    ], ahora);
    expect(r.mesesActivos, 1); // menos de un mes cuenta como uno
    // 1,000 ya gastados + 1,000 al mes por los ~1.57 meses que faltan.
    expect(
      r.proyeccionGasto,
      closeTo(1000 + 1000 * (12 - r.mesesTranscurridos), 0.01),
    );
    expect(r.proyeccionGasto, greaterThan(2500));
  });
}
