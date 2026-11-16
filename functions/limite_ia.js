// Contador de mensajes de IA por usuario según su membresía (ver planes.js).
// Vive en /usoIA/{uid}, que solo escribe el servidor.

const {getFirestore} = require("firebase-admin/firestore");
require("./admin.js");
const {planVigente, registrarUso, devolverUso} = require("./planes.js");

/// Cuenta un mensaje si el plan lo permite. Devuelve {permitido, plan,
/// limite, restantes}.
async function consumirMensajeIA(uid, ahora = new Date()) {
  const db = getFirestore();
  const suscripcionRef = db.collection("suscripciones").doc(uid);
  const usoRef = db.collection("usoIA").doc(uid);
  return db.runTransaction(async (tx) => {
    const [suscripcion, uso] = await Promise.all([tx.get(suscripcionRef), tx.get(usoRef)]);
    const resultado = registrarUso(uso.data(), planVigente(suscripcion.data()), ahora);
    if (resultado.permitido) tx.set(usoRef, resultado.uso);
    return resultado;
  });
}

/// Regresa el mensaje si DeepSeek falló (no se cobra un mensaje inútil).
async function devolverMensajeIA(uid, ahora = new Date()) {
  const db = getFirestore();
  const usoRef = db.collection("usoIA").doc(uid);
  await db.runTransaction(async (tx) => {
    const uso = await tx.get(usoRef);
    const devuelto = devolverUso(uso.data(), ahora);
    if (devuelto) tx.set(usoRef, devuelto);
  });
}

module.exports = {consumirMensajeIA, devolverMensajeIA};
