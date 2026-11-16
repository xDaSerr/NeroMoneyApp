import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/features/planes/data/membresia.dart';
import 'package:neromoney_app/features/presupuestos/data/planeacion.dart';
import 'package:neromoney_app/features/transactions/data/transaccion.dart';

Transaccion _mov(
  double monto,
  String categoria,
  DateTime fecha, {
  TipoTransaccion tipo = TipoTransaccion.gasto,
  String? transferencia,
}) => Transaccion(
  id: '$monto$categoria$fecha',
  monto: monto,
  tipo: tipo,
  categoria: categoria,
  cuentaId: 'c',
  fecha: fecha,
  transferenciaId: transferencia,
);

void main() {
  final ahora = DateTime(2026, 11, 13);

  test('presupuestos: gasto del mes, reembolsos, niveles y orden', () {
    final estados = EstadoPresupuesto.calcular(
      const [
        Presupuesto(id: 'a', categoria: 'Alimentación', limite: 1000),
        Presupuesto(id: 'b', categoria: 'Ocio', limite: 500),
        Presupuesto(id: 'c', categoria: 'Salud', limite: 400),
      ],
      [
        _mov(700, 'Alimentación', DateTime(2026, 11, 2)),
        _mov(150, 'Alimentación', DateTime(2026, 11, 10)),
        // Mes pasado y transferencias no cuentan.
        _mov(999, 'Alimentación', DateTime(2026, 10, 30)),
        _mov(300, 'Ocio', DateTime(2026, 11, 5), transferencia: 't'),
        _mov(600, 'Ocio', DateTime(2026, 11, 6)),
        // Un reembolso de Ocio resta.
        _mov(50, 'Ocio', DateTime(2026, 11, 7), tipo: TipoTransaccion.ingreso),
      ],
      ahora,
    );

    expect(estados.map((e) => e.presupuesto.categoria), [
      'Ocio',
      'Alimentación',
      'Salud',
    ]);
    expect(estados[0].gastado, 550);
    expect(estados[0].nivel, NivelPresupuesto.excedido);
    expect(estados[0].restante, -50);
    expect(estados[1].gastado, 850);
    expect(estados[1].nivel, NivelPresupuesto.aviso);
    expect(estados[2].gastado, 0);
    expect(estados[2].nivel, NivelPresupuesto.bien);
  });

  group('metas', () {
    MetaAhorro meta({
      required double ahorrado,
      required DateTime creada,
      DateTime? limite,
    }) => MetaAhorro(
      id: 'm',
      nombre: 'Viaje',
      objetivo: 12000,
      ahorrado: ahorrado,
      creada: creada,
      fechaLimite: limite,
    );

    test('sin abonos no inventa una fecha', () {
      final p = meta(ahorrado: 0, creada: ahora).proyectar(ahora);
      expect(p.fechaEstimada, isNull);
      expect(p.completada, isFalse);
    });

    test('a 1,000 al mes desde hace 3 meses llega en ~9 meses', () {
      final p = meta(
        ahorrado: 3000,
        creada: ahora.subtract(const Duration(days: 91)),
      ).proyectar(ahora);
      expect(p.ritmoMensual, closeTo(1003, 5));
      expect(p.fechaEstimada!.year, 2027);
      expect(p.fechaEstimada!.month, inInclusiveRange(7, 8));
    });

    test('con fecha límite dice cuánto juntar al mes y si llega', () {
      final p = meta(
        ahorrado: 3000,
        creada: ahora.subtract(const Duration(days: 91)),
        limite: DateTime(2027, 5, 31),
      ).proyectar(ahora);
      expect(p.llegaATiempo, isFalse);
      expect(p.necesarioPorMes, closeTo(9000 / 6.5, 60));
    });

    test('el primer abono del mismo día cuenta como un mes de ritmo', () {
      final p = meta(ahorrado: 1000, creada: ahora).proyectar(ahora);
      expect(p.ritmoMensual, 1000);
    });

    test('cumplida', () {
      final m = meta(ahorrado: 12500, creada: ahora);
      expect(m.completada, isTrue);
      expect(m.progreso, 1);
      expect(m.proyectar(ahora).completada, isTrue);
    });
  });

  test('límites por plan', () {
    expect(PlanNero.gratis.maxPresupuestos, 1);
    expect(PlanNero.gratis.maxMetas, 1);
    expect(PlanNero.plus.maxPresupuestos, isNull);
    expect(PlanNero.pro.maxMetas, isNull);
  });
}
