import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/features/reports/data/periodo_reporte.dart';
import 'package:neromoney_app/features/transactions/data/transaccion.dart';

void main() {
  final hoy = DateTime.now();
  final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);

  test('Día: hoy, ayer y fechas; un día completo de 4 en 4 horas', () {
    const seleccion = SeleccionPeriodo(TipoPeriodo.dia);
    final r = seleccion.rango;
    expect(r.etiqueta, 'Hoy');
    expect(r.desde, hoySinHora);
    expect(r.hasta, DateTime(hoy.year, hoy.month, hoy.day + 1));
    expect(r.esActual, isTrue);
    expect(seleccion.previa.rango.etiqueta, 'Ayer');
    expect(
      const SeleccionPeriodo(TipoPeriodo.dia, -2).rango.etiqueta,
      contains('${hoy.year}'),
    );
    expect(seleccion.puedeAvanzar, isFalse);
    expect(seleccion.previa.puedeAvanzar, isTrue);
    expect(seleccion.tramo, Tramo.horas);

    final buckets = calcularBuckets(seleccion, [
      Transaccion(
        id: 'a',
        monto: 80,
        tipo: TipoTransaccion.gasto,
        categoria: 'Alimentación',
        cuentaId: 'c',
        fecha: DateTime(hoy.year, hoy.month, hoy.day, 9, 30),
      ),
    ]);
    expect(buckets.map((b) => b.etiqueta), [
      '0h',
      '4h',
      '8h',
      '12h',
      '16h',
      '20h',
    ]);
    expect(buckets[2].gasto, 80);
  });

  test('rango personalizado: etiqueta, días incluidos y anterior del mismo '
      'tamaño', () {
    final r = SeleccionPeriodo.rango(
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 10),
    );
    expect(r.esPersonalizado, isTrue);
    expect(r.rango.desde, DateTime(2026, 11, 1));
    expect(r.rango.hasta, DateTime(2026, 11, 11)); // el 10 completo
    expect(r.rango.etiqueta, '1 nov – 10 nov 2026');
    expect(r.tramo, Tramo.dia);
    // Anterior: los 10 días de antes (22 al 31 de octubre).
    expect(r.previa.rango.desde, DateTime(2026, 10, 22));
    expect(r.previa.rango.hasta, DateTime(2026, 11, 1));
    expect(r.siguiente.rango.desde, DateTime(2026, 11, 11));

    final buckets = calcularBuckets(r, const []);
    expect(buckets, hasLength(10));
    expect(buckets.first.etiqueta, '1');
    expect(buckets.last.etiqueta, '10');
  });

  test('el tramo depende de la duración del rango', () {
    expect(
      SeleccionPeriodo.rango(
        DateTime(2026, 11, 5),
        DateTime(2026, 11, 5),
      ).tramo,
      Tramo.horas,
    );
    expect(
      SeleccionPeriodo.rango(
        DateTime(2026, 9, 1),
        DateTime(2026, 11, 10),
      ).tramo,
      Tramo.semana,
    );
    final largo = SeleccionPeriodo.rango(
      DateTime(2025, 12, 15),
      DateTime(2026, 11, 10),
    );
    expect(largo.tramo, Tramo.mes);
    final meses = calcularBuckets(largo, const []);
    expect(meses.first.etiqueta, 'Dic');
    expect(meses.last.etiqueta, 'Nov');
    expect(largo.rango.etiqueta, '15 dic 2025 – 10 nov 2026');
  });

  test('semana, mes y año siguen como antes', () {
    expect(const SeleccionPeriodo(TipoPeriodo.semana).tramo, Tramo.dia);
    expect(
      calcularBuckets(
        const SeleccionPeriodo(TipoPeriodo.semana),
        const [],
      ).map((b) => b.etiqueta),
      ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
    );
    expect(const SeleccionPeriodo(TipoPeriodo.mes).tramo, Tramo.semana);
    expect(
      calcularBuckets(const SeleccionPeriodo(TipoPeriodo.anio), const []),
      hasLength(12),
    );
    expect(const SeleccionPeriodo(TipoPeriodo.mes, -1).puedeAvanzar, isTrue);
  });
}
