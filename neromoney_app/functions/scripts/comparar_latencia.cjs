// Evaluación manual con datos ficticios. Solo llama al modelo; no escribe en Firestore.
// Requiere una sesión de Firebase autorizada y consume tokens de DeepSeek.
const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const OpenAI = require('openai');
const {cargarFuncion} = require('../test/cargar_funcion.cjs');

async function main() {
  if (!process.argv.includes('--ejecutar')) throw new Error('Usa --ejecutar para autorizar las llamadas de evaluación.');
  const cli = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib/bin/firebase.js');
  // Capturar en memoria; nunca imprimir ni guardar el secreto.
  const apiKey = execFileSync(process.execPath, [cli, 'functions:secrets:access',
    'DEEPSEEK_API_KEY', '--project', 'neromoneyapp'], {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();
  if (!apiKey || /\s/.test(apiKey)) throw new Error('No se pudo obtener el secreto.');
  const client = new OpenAI({apiKey, baseURL: 'https://api.deepseek.com', timeout: 45000, maxRetries: 0});
  const transaccion = (monto, tipo = 'gasto') => r => r.tipo === 'transaccion_extraida' && r.datos.tipo === tipo && r.datos.monto === monto;
  const casos = [
    ['cafe', 'Gasté 100 pesos en un café en efectivo', r => transaccion(100)(r) && r.datos.categoria === 'Alimentación' && /efectivo/i.test(r.datos.cuentaMencionada)],
    ['decimal', 'Gasté 35.50 pesos en pan en efectivo', transaccion(35.50)],
    ['ingreso', 'Recibí 5000 pesos de nómina en efectivo', transaccion(5000, 'ingreso')],
    ['consulta_gasto', '¿Cuánto gasté este mes?', r => r.tipo === 'consulta_gasto' && r.periodo === 'mes'],
    ['consulta_saldo', '¿Cuánto debo en mi Rappi Card?', r => r.tipo === 'consultar_saldo' && /rappi/i.test(r.cuentaMencionada)],
    ['compra_credito', 'Pagué con mi Rappi Card 100 pesos de café', transaccion(100)],
    ['abono_credito', 'Aboné 500 pesos a mi Rappi Card', r => r.tipo === 'pagar_tarjeta' && r.tipoPago === 'parcial' && r.monto === 500],
    ['corregir_saldo', 'Actualiza mi saldo de efectivo a 1000 pesos', r => r.tipo === 'actualizar_saldo' && r.nuevoSaldo === 1000],
    ['reembolso', 'Me devolvieron completo lo del taxi de ayer en efectivo', transaccion(80, 'ingreso')],
    ['monto_faltante', 'Gasté en un café en efectivo pero todavía no sé cuánto', r => r.tipo === 'mensaje'],
    ['negacion', 'No gasté nada hoy, no registres ningún movimiento', r => r.tipo === 'mensaje'],
  ];
  const resultados = [];
  async function ejecutar(caso, modo) {
    let metrica;
    const handler = cargarFuncion(async body => {
      const params = {...body};
      if (modo === 'antes') delete params.thinking;
      const inicio = performance.now();
      const respuesta = await client.chat.completions.create(params);
      metrica = {ms: Math.round(performance.now() - inicio), entrada: respuesta.usage?.prompt_tokens,
        salida: respuesta.usage?.completion_tokens, razonamiento: respuesta.usage?.completion_tokens_details?.reasoning_tokens ?? 0};
      return respuesta;
    });
    const ayer = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
    const respuesta = await handler.ejecutar({auth: {uid: 'evaluacion-sintetica'}, data: {
      mensaje: caso[1], historial: [], nombresCuentas: ['Efectivo', 'Rappi Card'],
      transaccionesRecientes: [{tipo: 'gasto', monto: 80, categoria: 'Transporte', descripcion: 'taxi', fecha: ayer, cuenta: 'Efectivo'}],
    }});
    const fila = {caso: caso[0], modo, ...metrica, correcto: caso[2](respuesta)};
    resultados.push(fila);
    console.log(JSON.stringify(fila));
    if (!fila.correcto) console.log(JSON.stringify({caso: caso[0], resultadoSintetico: respuesta}));
  }
  // Alternar el orden para reducir el sesgo por caché y carga del proveedor.
  for (let i = 0; i < 3; i++) {
    for (const modo of i % 2 ? ['despues', 'antes'] : ['antes', 'despues']) await ejecutar(casos[0], modo);
  }
  for (const caso of casos.slice(1)) await ejecutar(caso, 'despues');
  const destino = path.join(__dirname, '../../build/latencia-deepseek.json');
  fs.mkdirSync(path.dirname(destino), {recursive: true});
  fs.writeFileSync(destino, JSON.stringify({fecha: new Date().toISOString(), resultados}, null, 2));
  if (resultados.some(r => !r.correcto)) process.exitCode = 1;
}
main().catch(e => {
  // No serializar excepciones del SDK/CLI: pueden contener cabeceras o secretos.
  console.error('Evaluación interrumpida. Estado:', e.status ?? e.code ?? 'error');
  process.exitCode = 1;
});
