const {test} = require('node:test');
const assert = require('node:assert/strict');
const {generarCsv, partir} = require('../respaldo.js');

const BOM = String.fromCharCode(0xFEFF);

test('CSV del respaldo: orden, signos, moneda por cuenta y sin fórmulas', () => {
  const csv = generarCsv([
    {tipo: 'ingreso', monto: 9000, categoria: 'Nómina', descripcion: '=SUMA(A1)', cuentaId: 'a', fecha: new Date('2026-11-01T18:00:00Z')},
    {tipo: 'gasto', monto: 20, categoria: 'Ocio', descripcion: 'Netflix, plan "básico"', cuentaId: 'b', fecha: new Date('2026-10-05T18:00:00Z')},
  ], [{id: 'a', nombre: 'Nu'}, {id: 'b', nombre: 'Cuenta USD', moneda: 'USD'}], 'MXN');
  // BOM al inicio para que Excel lea bien los acentos (trim() lo quitaría).
  assert.ok(csv.startsWith(BOM));
  const lineas = csv.slice(1).trim().split('\n');
  assert.equal(lineas[0], 'Fecha,Tipo,Categoría,Descripción,Cuenta,Monto,Moneda');
  assert.equal(lineas[1], '2026-10-05,Gasto,Ocio,"Netflix, plan ""básico""",Cuenta USD,-20.00,USD');
  assert.equal(lineas[2], "2026-11-01,Ingreso,Nómina,'=SUMA(A1),Nu,9000.00,MXN");
});

test('partir corta en saltos de línea y no pierde nada', () => {
  const texto = Array.from({length: 1000}, (_, i) => `linea ${i}`).join('\n') + '\n';
  const partes = partir(texto, 500);
  assert.ok(partes.length > 10);
  assert.equal(partes.join(''), texto);
  for (const p of partes.slice(0, -1)) assert.ok(p.endsWith('\n') && p.length <= 500);
});
