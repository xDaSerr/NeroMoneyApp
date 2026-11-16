// Tipos de cambio para la multimoneda (Pro). Se piden a open.er-api.com
// (gratis, sin clave; cubre MXN, USD, EUR, COP, ARS, CLP, PEN, GTQ y BRL)
// como máximo cada 12 horas y se guardan en /tiposCambio/usd, que la app
// lee. A ese servicio no se le manda ningún dato del usuario.

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {getFirestore} = require("firebase-admin/firestore");
require("./admin.js");

const MONEDAS = ["MXN", "USD", "EUR", "COP", "ARS", "CLP", "PEN", "GTQ", "BRL"];
const VIGENCIA_MS = 12 * 60 * 60 * 1000;

/// Solo las monedas de la app, con números válidos.
function filtrarTasas(rates) {
  const tasas = {};
  for (const m of MONEDAS) {
    const v = rates && rates[m];
    if (typeof v === "number" && Number.isFinite(v) && v > 0) tasas[m] = v;
  }
  return tasas;
}

/// [monto] de la moneda [de] a la moneda [a] con tasas "por 1 USD". Sin
/// tasa conocida se deja igual.
function convertir(monto, de, a, tasas) {
  if (!de || !a || de === a) return monto;
  const x = tasas && tasas[de];
  const y = tasas && tasas[a];
  if (!x || !y) return monto;
  return monto / x * y;
}

/// Lee las tasas guardadas y las renueva si tienen más de 12 horas.
async function obtenerTasas(ahora = Date.now()) {
  const ref = getFirestore().collection("tiposCambio").doc("usd");
  const guardado = (await ref.get()).data();
  if (guardado && guardado.actualizado && ahora - guardado.actualizado < VIGENCIA_MS) {
    return guardado;
  }
  try {
    const respuesta = await fetch("https://open.er-api.com/v6/latest/USD");
    const datos = await respuesta.json();
    if (!respuesta.ok || datos.result !== "success") throw new Error(`estado ${respuesta.status}`);
    const nuevo = {
      tasas: filtrarTasas(datos.rates),
      fecha: datos.time_last_update_utc || "",
      actualizado: ahora,
      fuente: "ExchangeRate-API (open.er-api.com)",
    };
    await ref.set(nuevo);
    return nuevo;
  } catch (error) {
    logger.warn("tipos_cambio_error", {mensaje: String(error.message || error)});
    // Mejor unas tasas de ayer que ninguna.
    if (guardado) return guardado;
    throw new HttpsError("unavailable", "No pudimos obtener los tipos de cambio.");
  }
}

exports.tiposDeCambio = onCall({region: "us-central1"}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Inicia sesión.");
  const {tasas, fecha, fuente} = await obtenerTasas();
  return {tasas, fecha, fuente};
});

module.exports.MONEDAS = MONEDAS;
module.exports.filtrarTasas = filtrarTasas;
module.exports.convertir = convertir;
module.exports.obtenerTasas = obtenerTasas;
