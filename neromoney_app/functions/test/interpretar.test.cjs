const {test} = require('node:test');
const assert = require('node:assert/strict');
const {cargarFuncion} = require('./cargar_funcion.cjs');

const peticion = {auth: {uid: 'prueba'}, data: {
  mensaje: 'Gasté 100 pesos en un café en efectivo',
  historial: [{role: 'assistant', content: '¿Qué quieres registrar?'}],
  transaccionesRecientes: [{tipo: 'gasto', monto: 50, categoria: 'Alimentación'}],
  nombresCuentas: ['Efectivo', 'Rappi Card'],
}};
const completion = (nombre, argumentos) => ({
  choices: [{message: {tool_calls: [{function: {name: nombre, arguments: JSON.stringify(argumentos)}}]}}],
  usage: {prompt_tokens: 120, completion_tokens: 40},
});

test('extracción sin razonamiento conserva contexto, herramientas y contrato', async () => {
  let enviado;
  const datos = {tipo: 'gasto', monto: 100, categoria: 'Alimentación', descripcion: 'café', cuentaMencionada: 'Efectivo'};
  const funcion = cargarFuncion(async (body) => {
    enviado = body;
    return completion('registrar_transaccion', datos);
  });
  const resultado = await funcion.ejecutar(peticion);
  assert.deepEqual(JSON.parse(JSON.stringify(resultado)), {tipo: 'transaccion_extraida', datos});
  assert.equal(enviado.thinking.type, 'disabled');
  assert.equal(enviado.messages.at(-1).content, peticion.data.mensaje);
  assert.equal(enviado.messages.at(-2).role, 'assistant');
  assert.equal(enviado.tools.length, 5);
  assert.match(enviado.messages[1].content, /Alimentación/);
  assert.match(enviado.messages[2].content, /Rappi Card/);
  assert.equal(funcion.registros[0].resultado, 'ok');
  const registro = JSON.stringify(funcion.registros);
  for (const privado of ['café', 'Efectivo', 'Rappi Card', 'secreto-simulado']) {
    assert.equal(registro.includes(privado), false);
  }
});

for (const [herramienta, argumentos, tipo] of [
  ['consultar_gasto_periodo', {periodo: 'dia', diasAtras: 1, cuentaMencionada: 'Efectivo'}, 'consulta_gasto'],
  ['consultar_saldo_cuenta', {cuentaMencionada: 'Efectivo'}, 'consultar_saldo'],
  ['actualizar_saldo_cuenta', {cuentaMencionada: 'Efectivo', nuevoSaldo: 500}, 'actualizar_saldo'],
  ['pagar_tarjeta_credito', {cuentaMencionada: 'Rappi Card', tipoPago: 'parcial', monto: 100}, 'pagar_tarjeta'],
]) {
  test(`conserva ${herramienta}`, async () => {
    const funcion = cargarFuncion(async () => completion(herramienta, argumentos));
    assert.equal((await funcion.ejecutar(peticion)).tipo, tipo);
  });
}
test('sin herramienta responde texto sin confirmar un registro', async () => {
  const funcion = cargarFuncion(async () => ({choices: [{message: {content: '¿Cuánto gastaste?'}}]}));
  assert.equal((await funcion.ejecutar(peticion)).tipo, 'mensaje');
});
test('rechaza peticiones sin sesión y mensajes vacíos antes de llamar a DeepSeek', async () => {
  let llamadas = 0;
  const funcion = cargarFuncion(async () => { llamadas++; });
  await assert.rejects(funcion.ejecutar({data: peticion.data}), {code: 'unauthenticated'});
  await assert.rejects(funcion.ejecutar({auth: peticion.auth, data: {mensaje: '  '}}), {code: 'invalid-argument'});
  assert.equal(llamadas, 0);
});
test('un fallo de DeepSeek deja una medición sin exponer el error completo', async () => {
  const funcion = cargarFuncion(async () => { throw new Error('dato-privado'); });
  await assert.rejects(funcion.ejecutar(peticion));
  assert.equal(funcion.registros[0].resultado, 'error');
  assert.equal(JSON.stringify(funcion.registros).includes('dato-privado'), false);
});
