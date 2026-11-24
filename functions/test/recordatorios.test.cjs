const {test} = require('node:test');
const assert = require('node:assert/strict');
const {relojLocal, recordatoriosPendientes, textoDe} = require('../recordatorios.js')._paraPruebas;

// 23 nov 2026, 20:05 en Mexicali (UTC-8) = 04:05 UTC del 24.
const ahora = new Date('2026-11-24T04:05:00Z');

test('usa la zona horaria del usuario', () => {
  assert.deepEqual(relojLocal(ahora, 'America/Tijuana'), {fecha: '2026-11-23', minutos: 20 * 60 + 5});
  assert.equal(relojLocal(ahora, 'zona/inventada').fecha, '2026-11-23');
});

test('manda el de la noche dentro de su ventana y solo una vez al día', () => {
  const perfil = {zonaHoraria: 'America/Tijuana', horaRecordatorio1: 14 * 60, horaRecordatorio2: 20 * 60};
  assert.deepEqual(recordatoriosPendientes(perfil, ahora).pendientes, ['noche']);
  const yaEnviado = {...perfil, recordatoriosEnviados: {noche: '2026-11-23'}};
  assert.deepEqual(recordatoriosPendientes(yaEnviado, ahora).pendientes, []);
  const otraHora = {...perfil, horaRecordatorio2: 21 * 60};
  assert.deepEqual(recordatoriosPendientes(otraHora, ahora).pendientes, []);
});

test('el texto usa el nombre de la asistente y el apodo', () => {
  const t = textoDe('noche', {nombreAsistente: 'Lucy', apodo: 'Dani'});
  assert.equal(t.title, 'Lucy 👋');
  assert.match(t.body, /Hola, Dani\./);
});
