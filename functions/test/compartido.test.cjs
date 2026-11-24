const {test} = require('node:test');
const assert = require('node:assert/strict');
const {nuevoCodigo, normalizarCodigo, limpiarNombre, ALFABETO} = require('../compartido.js')._paraPruebas;

test('códigos de 6 caracteres sin letras que se confunden', () => {
  for (let i = 0; i < 200; i++) {
    const c = nuevoCodigo();
    assert.equal(c.length, 6);
    for (const letra of c) assert.ok(ALFABETO.includes(letra));
    assert.doesNotMatch(c, /[01OIL]/);
  }
});

test('el código escrito a mano se normaliza', () => {
  assert.equal(normalizarCodigo(' ab-c 12d '), 'ABC12D');
  assert.equal(normalizarCodigo(null), '');
});

test('nombres recortados y con valor por defecto', () => {
  assert.equal(limpiarNombre('  Casa  ', 'X'), 'Casa');
  assert.equal(limpiarNombre('', 'Nuestro hogar'), 'Nuestro hogar');
  assert.equal(limpiarNombre('a'.repeat(80), 'X').length, 40);
});
