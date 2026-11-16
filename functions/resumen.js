// Resumen mensual inteligente (Plus y Pro): Lucy lee los números del mes
// y escribe un titular, 3-4 observaciones y un consejo.
//
// - El plan se revisa aquí, en el servidor (Gratis no puede pedirlo).
// - Los movimientos los lee el servidor de Firestore: la app solo manda el
//   mes.
// - Se guarda en /resumenesIA/{uid}/meses/{mes} (solo lo escribe el
//   servidor) y se regenera como máximo una vez al día por mes, así un
//   botón presionado mil veces no cuesta mil llamadas a DeepSeek.

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const {getFirestore} = require("firebase-admin/firestore");
const OpenAI = require("openai");
require("./admin.js");
const {planVigente, claveDia} = require("./planes.js");
const {
  mesActual,
  mesValido,
  mesAnterior,
  rangoMes,
  agregarMes,
  limpiarResumen,
  mensajesParaIA,
} = require("./resumen_datos.js");
const {convertir, obtenerTasas} = require("./monedas.js");

const deepseekApiKey = defineSecret("DEEPSEEK_API_KEY");
const MODELO = "deepseek-v4-flash";

exports.resumenMensualIA = onCall(
  {secrets: [deepseekApiKey], region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Inicia sesión para ver tu resumen.");
    }
    const uid = request.auth.uid;
    const ahora = new Date();
    const mes = (request.data || {}).mes || mesActual(ahora);
    if (!mesValido(mes, ahora)) {
      throw new HttpsError("invalid-argument", "Mes no válido.");
    }

    const db = getFirestore();
    const suscripcion = await db.collection("suscripciones").doc(uid).get();
    if (planVigente(suscripcion.data()) === "gratis") {
      throw new HttpsError(
          "permission-denied",
          "El resumen inteligente es parte de NeroMoney Plus.",
      );
    }

    const enCurso = mes === mesActual(ahora);
    const ref = db.collection("resumenesIA").doc(uid).collection("meses").doc(mes);
    const guardado = (await ref.get()).data();
    // Ya se generó hoy, o el mes ya cerró y el resumen se hizo después:
    // no hay nada nuevo que contar.
    if (guardado && (guardado.generadoDia === claveDia(ahora) || (!enCurso && guardado.mesCerrado))) {
      return guardado;
    }

    // Movimientos del mes y del anterior (para comparar).
    const {desde} = rangoMes(mesAnterior(mes));
    const {hasta} = rangoMes(mes);
    const usuario = db.collection("usuarios").doc(uid);
    const [snap, perfil, cuentas] = await Promise.all([
      usuario.collection("transacciones")
          .where("fecha", ">=", desde)
          .where("fecha", "<", hasta)
          .get(),
      usuario.get(),
      usuario.collection("cuentas").get(),
    ]);
    // Multimoneda (Pro): los movimientos de cuentas en otra moneda se
    // convierten a la principal antes de sumar.
    const principal = (perfil.data() || {}).moneda || "MXN";
    const monedaPorCuenta = {};
    for (const c of cuentas.docs) {
      const m = c.data().moneda;
      if (m && m !== principal) monedaPorCuenta[c.id] = m;
    }
    const tasas = Object.keys(monedaPorCuenta).length > 0 ?
      (await obtenerTasas()).tasas : {};
    const transacciones = snap.docs.map((d) => {
      const t = d.data();
      const moneda = monedaPorCuenta[t.cuentaId];
      return {
        ...t,
        monto: moneda ? convertir(t.monto, moneda, principal, tasas) : t.monto,
        fecha: t.fecha && t.fecha.toDate ? t.fecha.toDate() : new Date(0),
      };
    });
    const actual = agregarMes(transacciones, mes);
    const anterior = agregarMes(transacciones, mesAnterior(mes));

    const base = {
      mes,
      generadoDia: claveDia(ahora),
      generado: ahora.toISOString(),
      mesCerrado: !enCurso,
    };
    if (actual.movimientos === 0) {
      const vacio = {...base, sinDatos: true};
      await ref.set(vacio);
      return vacio;
    }

    const datosPerfil = perfil.data() || {};
    const openai = new OpenAI({baseURL: "https://api.deepseek.com", apiKey: deepseekApiKey.value()});
    const inicio = performance.now();
    let resumen = null;
    try {
      const completion = await openai.chat.completions.create({
        model: MODELO,
        thinking: {type: "disabled"},
        response_format: {type: "json_object"},
        messages: mensajesParaIA({
          actual,
          anterior,
          enCurso,
          moneda: datosPerfil.moneda || "MXN",
          nombreAsistente: datosPerfil.nombreAsistente || "Lucy",
        }),
      });
      resumen = limpiarResumen(completion.choices[0].message.content);
    } finally {
      // Solo métricas: nunca montos, categorías ni el texto generado.
      logger.info("resumen_mensual", {
        duracionMs: Math.round(performance.now() - inicio),
        resultado: resumen ? "ok" : "error",
      });
    }
    if (!resumen) {
      throw new HttpsError("unavailable", "No pude escribir tu resumen ahora. Intenta en un momento.");
    }

    const resultado = {...base, ...resumen, gastoTotal: actual.gastoTotal, ingresos: actual.ingresos};
    await ref.set(resultado);
    return resultado;
  },
);
