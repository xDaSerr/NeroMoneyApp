const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Ejecuta el mismo handler sin desplegar, sin Firestore y sin secretos reales.
function cargarFuncion(crearCompletion, {codigo} = {}) {
  const registros = [];
  const sandbox = {
    exports: {}, performance,
    require(nombre) {
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
  return {ejecutar: sandbox.exports.interpretarMensajeIA, registros};
}
module.exports = {cargarFuncion};
