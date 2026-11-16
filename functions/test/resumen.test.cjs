const {test} = require('node:test');
const assert = require('node:assert/strict');
const r = require('../resumen_datos.js');

const AHORA = new Date('2026-11-13T18:00:00Z');

test('mesValido: el mes en curso y los 11 anteriores', () => {
  assert.equal(r.mesValido('2026-11', AHORA), true);
  assert.equal(r.mesValido('2025-12', AHORA), true);
  assert.equal(r.mesValido('2025-11', AHORA), false);
  assert.equal(r.mesValido('2026-12', AHORA), false);
  assert.equal(r.mesValido('2026-13', AHORA), false);
  assert.equal(r.mesValido('../otro', AHORA), false);
  assert.equal(r.mesValido(undefined, AHORA), false);
});

test('mesAnterior y rangoMes en hora de México', () => {
  assert.equal(r.mesAnterior('2026-01'), '2025-12');
  assert.equal(r.mesAnterior('2026-11'), '2026-10');
  const {desde, hasta} = r.rangoMes('2026-11');
  assert.equal(desde.toISOString(), '2026-11-01T06:00:00.000Z');
  assert.equal(hasta.toISOString(), '2026-12-01T06:00:00.000Z');
});

test('agregarMes: neto por categoría, sin transferencias ni ajustes', () => {
  const f = (iso) => new Date(iso);
  const datos = r.agregarMes([
    {tipo: 'gasto', monto: 1000, categoria: 'Alimentación', descripcion: 'Súper', fecha: f('2026-11-03T18:00:00Z')},
    {tipo: 'gasto', monto: 300, categoria: 'Ocio', descripcion: 'Cine', fecha: f('2026-11-05T18:00:00Z')},
    {tipo: 'ingreso', monto: 100, categoria: 'Ocio', descripcion: 'Reembolso', fecha: f('2026-11-06T18:00:00Z')},
    {tipo: 'ingreso', monto: 9000, categoria: 'Nómina', fecha: f('2026-11-01T18:00:00Z')},
    {tipo: 'ingreso', monto: 500, categoria: 'Pago de tarjeta', fecha: f('2026-11-02T18:00:00Z')},
    {tipo: 'gasto', monto: 999, categoria: 'Otro', transferenciaId: 't', fecha: f('2026-11-04T18:00:00Z')},
    {tipo: 'gasto', monto: 50, categoria: 'Ajuste', fecha: f('2026-11-04T18:00:00Z')},
    // 31 de octubre a las 23:00 en México: es de octubre.
    {tipo: 'gasto', monto: 777, categoria: 'Ocio', fecha: f('2026-11-01T05:00:00Z')},
  ], '2026-11');

  assert.equal(datos.gastoTotal, 1200);
  assert.equal(datos.ingresos, 9000);
  assert.equal(datos.balance, 7800);
  assert.deepEqual(datos.porCategoria, [
    {categoria: 'Alimentación', monto: 1000},
    {categoria: 'Ocio', monto: 200},
  ]);
  assert.equal(datos.mayoresGastos[0].descripcion, 'Súper');
  assert.equal(datos.movimientos, 5);
});

test('limpiarResumen solo acepta la forma esperada y recorta', () => {
  assert.equal(r.limpiarResumen('no es json'), null);
  assert.equal(r.limpiarResumen('{"titular": ""}'), null);
  assert.equal(r.limpiarResumen({titular: 'Hola', puntos: []}), null);
  const limpio = r.limpiarResumen(JSON.stringify({
    titular: '  Gastaste menos  ',
    puntos: ['uno', 2, '', 'dos', 'tres', 'cuatro', 'cinco'],
    consejo: 'x'.repeat(500),
    extra: 'se ignora',
  }));
  assert.deepEqual(Object.keys(limpio), ['titular', 'puntos', 'consejo']);
  assert.equal(limpio.titular, 'Gastaste menos');
  assert.deepEqual(limpio.puntos, ['uno', 'dos', 'tres', 'cuatro']);
  assert.equal(limpio.consejo.length, 220);
});

test('mensajesParaIA lleva los números y pide JSON', () => {
  const actual = {mes: '2026-11', movimientos: 3, gastoTotal: 1200};
  const m = r.mensajesParaIA({
    actual, anterior: {movimientos: 0}, moneda: 'MXN', nombreAsistente: 'Nova', enCurso: true,
  });
  assert.match(m[0].content, /Nova/);
  assert.match(m[0].content, /JSON/);
  const contexto = JSON.parse(m[1].content);
  assert.equal(contexto.mes, 'noviembre de 2026');
  assert.equal(contexto.mesAnterior, 'sin movimientos');
  assert.equal(contexto.esteMes.gastoTotal, 1200);
});
