const {test} = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const planes = require('../planes.js');
const {cargarFuncion} = require('./cargar_funcion.cjs');

// 13 nov 2026, 12:00 en México.
const AHORA = new Date('2026-11-13T18:00:00Z');

test('Gratis: 15 mensajes al mes y luego se bloquea', () => {
  let uso;
  for (let i = 0; i < 15; i++) {
    const r = planes.registrarUso(uso, 'gratis', AHORA);
    assert.equal(r.permitido, true);
    uso = r.uso;
  }
  assert.equal(uso.enMes, 15);
  assert.equal(planes.registrarUso(uso, 'gratis', AHORA).permitido, false);
  // Mes nuevo: se reinicia.
  assert.equal(planes.registrarUso(uso, 'gratis', new Date('2026-12-01T18:00:00Z')).permitido, true);
});

test('Plus: tope diario de 100 que se reinicia a la medianoche de México', () => {
  const lleno = {dia: '2026-11-13', enDia: 100, mes: '2026-11', enMes: 400};
  assert.equal(planes.registrarUso(lleno, 'plus', AHORA).permitido, false);
  assert.equal(planes.registrarUso(lleno, 'pro', AHORA).permitido, true);
  // 05:59 UTC del 14 = 23:59 del 13 en México: sigue bloqueado.
  assert.equal(planes.registrarUso(lleno, 'plus', new Date('2026-11-14T05:59:00Z')).permitido, false);
  assert.equal(planes.registrarUso(lleno, 'plus', new Date('2026-11-14T06:01:00Z')).permitido, true);
});

test('devolverUso deshace el último mensaje sin bajar de cero', () => {
  const r = planes.registrarUso(undefined, 'gratis', AHORA);
  assert.deepEqual(planes.devolverUso(r.uso, AHORA), {dia: '2026-11-13', enDia: 0, mes: '2026-11', enMes: 0});
});

test('planVigente toma el mejor plan con acceso e ignora los revocados', () => {
  assert.equal(planes.planVigente(undefined), 'gratis');
  assert.equal(planes.planVigente({suscripciones: {
    a: {plan: 'plus', estado: 'active'},
    b: {plan: 'pro', estado: 'canceled'},
  }}), 'plus');
  assert.equal(planes.planVigente({suscripciones: {
    a: {plan: 'plus', estado: 'active'},
    b: {plan: 'pro', estado: 'past_due'},
  }}), 'pro');
  assert.equal(planes.planVigente({suscripciones: {a: {plan: 'pro', estado: 'unpaid'}}}), 'gratis');
});

test('productoAPlan solo reconoce los productos configurados', () => {
  const productos = {plus: {mensual: 'p1', anual: 'p2'}, pro: {mensual: 'p3', anual: ''}};
  assert.equal(planes.productoAPlan('p2', productos), 'plus');
  assert.equal(planes.productoAPlan('p3', productos), 'pro');
  assert.equal(planes.productoAPlan('otro', productos), null);
  assert.equal(planes.productoAPlan('', productos), null);
});

test('origenPermitido no deja redirigir a sitios ajenos', () => {
  assert.equal(planes.origenPermitido('http://localhost:5000'), 'http://localhost:5000');
  assert.equal(planes.origenPermitido('https://neromoneyapp.firebaseapp.com'), 'https://neromoneyapp.firebaseapp.com');
  assert.equal(planes.origenPermitido('https://malicioso.com'), 'https://neromoneyapp.web.app');
  assert.equal(planes.origenPermitido('http://localhost.malicioso.com'), 'https://neromoneyapp.web.app');
  assert.equal(planes.origenPermitido(undefined), 'https://neromoneyapp.web.app');
});

function firmar(clave, id, marca, cuerpo) {
  return 'v1,' + crypto.createHmac('sha256', clave).update(`${id}.${marca}.${cuerpo}`).digest('base64');
}

test('firmaValida acepta Standard Webhooks y el formato anterior de Polar', () => {
  const cuerpo = '{"type":"subscription.active"}';
  const ahoraSeg = 1_800_000_000;
  const marca = String(ahoraSeg);
  const claveBytes = crypto.randomBytes(24);
  const secretoNuevo = 'whsec_' + claveBytes.toString('base64');
  const encabezados = (firma) => ({'webhook-id': 'msg_1', 'webhook-timestamp': marca, 'webhook-signature': firma});

  // Standard Webhooks: clave = base64 decodificado.
  assert.equal(planes.firmaValida({cuerpo, ahoraSeg, secreto: secretoNuevo,
    encabezados: encabezados(firmar(claveBytes, 'msg_1', marca, cuerpo))}), true);
  // Formato anterior: clave = bytes del secreto completo.
  const secretoViejo = 'polar_whs_abc123';
  assert.equal(planes.firmaValida({cuerpo, ahoraSeg, secreto: secretoViejo,
    encabezados: encabezados('v1,xxx ' + firmar(Buffer.from(secretoViejo), 'msg_1', marca, cuerpo))}), true);

  // Cuerpo alterado, secreto equivocado o marca vieja: se rechaza.
  const firma = firmar(claveBytes, 'msg_1', marca, cuerpo);
  assert.equal(planes.firmaValida({cuerpo: cuerpo + ' ', ahoraSeg, secreto: secretoNuevo, encabezados: encabezados(firma)}), false);
  assert.equal(planes.firmaValida({cuerpo, ahoraSeg, secreto: 'whsec_' + crypto.randomBytes(24).toString('base64'), encabezados: encabezados(firma)}), false);
  assert.equal(planes.firmaValida({cuerpo, ahoraSeg: ahoraSeg + 600, secreto: secretoNuevo, encabezados: encabezados(firma)}), false);
  assert.equal(planes.firmaValida({cuerpo, ahoraSeg, secreto: secretoNuevo, encabezados: {}}), false);
});

test('datosDeSuscripcion y uidDeSuscripcion leen el payload de Polar', () => {
  const productos = {plus: {mensual: 'p1', anual: 'p2'}, pro: {mensual: 'p3', anual: 'p4'}};
  const sub = {
    id: 's1', status: 'active', product_id: 'p4', current_period_end: '2027-11-13T00:00:00Z',
    cancel_at_period_end: true, modified_at: '2026-11-13T18:00:00Z',
    customer: {external_id: 'uid-1'}, metadata: {},
  };
  assert.deepEqual(planes.datosDeSuscripcion(sub, productos), {
    plan: 'pro', estado: 'active', productoId: 'p4', periodoFin: '2027-11-13T00:00:00Z',
    cancelaAlFinal: true, modificado: '2026-11-13T18:00:00Z',
  });
  assert.equal(planes.uidDeSuscripcion(sub), 'uid-1');
  assert.equal(planes.uidDeSuscripcion({customer: {}, metadata: {uid: 'uid-2'}}), 'uid-2');
  assert.equal(planes.uidDeSuscripcion({}), null);
});

test('interpretarMensajeIA rechaza al llegar al límite sin llamar a DeepSeek', async () => {
  let llamadas = 0;
  const funcion = cargarFuncion(async () => { llamadas++; }, {
    uso: {permitido: false, plan: 'gratis', limite: {periodo: 'mes', maximo: 15}},
  });
  await assert.rejects(
    funcion.ejecutar({auth: {uid: 'u'}, data: {mensaje: 'gasté 100'}}),
    (e) => e.code === 'resource-exhausted' && /15 mensajes gratis/.test(e.message),
  );
  assert.equal(llamadas, 0);
});

test('si DeepSeek falla, el mensaje se devuelve', async () => {
  const funcion = cargarFuncion(async () => { throw new Error('caído'); });
  await assert.rejects(funcion.ejecutar({auth: {uid: 'u'}, data: {mensaje: 'gasté 100'}}));
  assert.deepEqual(funcion.contador, {consumidos: 1, devueltos: 1});
});

const monedas = require('../monedas.js');

test('monedas: filtra tasas y convierte por medio del dólar', () => {
  const tasas = monedas.filtrarTasas({MXN: 18, EUR: 0.9, USD: 1, JPY: 150, COP: 'x', ARS: -1});
  assert.deepEqual(tasas, {MXN: 18, USD: 1, EUR: 0.9});
  assert.equal(monedas.convertir(100, 'USD', 'MXN', tasas), 1800);
  assert.equal(monedas.convertir(90, 'EUR', 'USD', tasas), 100);
  assert.equal(monedas.convertir(100, 'MXN', 'MXN', tasas), 100);
  // Sin tasa conocida no inventa: deja el monto igual.
  assert.equal(monedas.convertir(100, 'CLP', 'MXN', tasas), 100);
});
