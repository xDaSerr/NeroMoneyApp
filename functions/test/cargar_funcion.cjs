const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Ejecuta el mismo handler sin desplegar, sin Firestore y sin secretos reales.
// `uso`: lo que devuelve el contador de mensajes (por defecto, permitido).
function cargarFuncion(crearCompletion, {codigo, uso} = {}) {
  const registros = [];
  const contador = {consumidos: 0, devueltos: 0};
  const sandbox = {
    exports: {}, performance,
    require(nombre) {
      if (nombre === './planes.js') return require('../planes.js');
      if (nombre === './pagos.js') return {};
      if (nombre === './resumen.js') return {};
      if (nombre === './monedas.js') return {};
      if (nombre === './ticket.js') return {};
      if (nombre === './respaldo.js') return {};
      if (nombre === './limite_ia.js') return {
        consumirMensajeIA: async () => {
          contador.consumidos++;
          return uso ?? {permitido: true, plan: 'gratis', limite: {periodo: 'mes', maximo: 15}};
        },
        devolverMensajeIA: async () => { contador.devueltos++; },
      };
      if (nombre === 'firebase-functions/v2/https') return {
        onCall: (_, handler) => handler,
        HttpsError: class extends Error {
          constructor(code, message) { super(message); this.code = code; }
        },
      };
      if (nombre === 'firebase-functions/params') return {
        defineSecret: () => ({value: () => 'secreto-simulado'}),
      };
      if (nombre === 'firebase-functions/logger') return {
        info: (evento, datos) => registros.push({evento, ...datos}),
      };
      if (nombre === 'openai') return class {
        chat = {completions: {create: crearCompletion}};
      };
      throw new Error(`Dependencia inesperada: ${nombre}`);
    },
  };
  vm.runInNewContext(codigo ?? fs.readFileSync(path.join(__dirname, '../index.js'), 'utf8'), sandbox);
  return {ejecutar: sandbox.exports.interpretarMensajeIA, registros, contador};
}
module.exports = {cargarFuncion};
