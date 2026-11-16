const {test} = require('node:test');
const assert = require('node:assert/strict');
const {limpiarTicket, imagenValida} = require('../ticket.js');

const HOY = '2026-11-13';

test('limpiarTicket acepta un ticket bien leído', () => {
  assert.deepEqual(
    limpiarTicket('{"esTicket": true, "monto": 245.567, "comercio": " OXXO ", "categoria": "Alimentación", "fecha": "2026-11-10"}', HOY),
    {esTicket: true, monto: 245.57, comercio: 'OXXO', categoria: 'Alimentación', fecha: '2026-11-10'},
  );
});

test('limpiarTicket descarta lo que no es ticket o viene mal', () => {
  assert.deepEqual(limpiarTicket('{"esTicket": false}', HOY), {esTicket: false});
  assert.deepEqual(limpiarTicket('{"monto": -5}', HOY), {esTicket: false});
  assert.deepEqual(limpiarTicket('{"monto": "abc"}', HOY), {esTicket: false});
  assert.equal(limpiarTicket('no es json', HOY), null);
  // Categoría inventada → Otro; fecha futura o mal formada → null.
  const r = limpiarTicket({monto: 99, categoria: 'Antojos', fecha: '2027-01-01'}, HOY);
  assert.equal(r.categoria, 'Otro');
  assert.equal(r.fecha, null);
  assert.equal(limpiarTicket({monto: 99, fecha: '13/11/2026'}, HOY).fecha, null);
});

test('imagenValida: solo imágenes en base64 y de tamaño razonable', () => {
  const b64 = 'A'.repeat(200);
  assert.equal(imagenValida(`data:image/png;base64,${b64}`), `data:image/png;base64,${b64}`);
  assert.equal(imagenValida(b64), `data:image/jpeg;base64,${b64}`);
  assert.equal(imagenValida('data:text/html;base64,' + b64), null);
  assert.equal(imagenValida('https://sitio.com/foto.jpg'), null);
  assert.equal(imagenValida('A'.repeat(6_000_000)), null);
  assert.equal(imagenValida(undefined), null);
});
