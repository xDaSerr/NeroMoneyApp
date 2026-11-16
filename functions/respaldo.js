// Respaldo automático (Pro): cada día 1 se guarda una copia en CSV de
// todos los movimientos de cada usuario Pro, y el usuario puede pedir una
// al momento (una vez al día). Se guardan las últimas 12 en
// /respaldos/{uid}/copias/{YYYY-MM}, que solo escribe el servidor.
//
// Va en Firestore (no en Cloud Storage, que el proyecto no tiene activo):
// el CSV se parte en trozos de ~700 KB para no pasar del límite de 1 MB
// por documento.

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const {getFirestore} = require("firebase-admin/firestore");
require("./admin.js");
const {planVigente, claveDia} = require("./planes.js");

const TAMANIO_PARTE = 700 * 1024;
const COPIAS_GUARDADAS = 12;

function celda(v) {
  const texto = String(v == null ? "" : v);
  const limpio = texto.replace(/"/g, "\"\"");
  // Que Excel no lo tome como fórmula.
  const seguro = /^[=+\-@]/.test(limpio) ? `'${limpio}` : limpio;
  return /[",\n\r]/.test(seguro) ? `"${seguro}"` : seguro;
}

/// CSV de movimientos (mismas columnas que "Exportar" en la app).
function generarCsv(transacciones, cuentas, monedaPrincipal) {
  const nombre = {};
  const moneda = {};
  for (const c of cuentas) {
    nombre[c.id] = c.nombre || "";
    moneda[c.id] = c.moneda || monedaPrincipal;
  }
  const lineas = ["﻿Fecha,Tipo,Categoría,Descripción,Cuenta,Monto,Moneda"];
  const ordenadas = [...transacciones].sort((a, b) => a.fecha - b.fecha);
  for (const t of ordenadas) {
    const tipo = t.transferenciaId ? "Transferencia" : t.tipo === "gasto" ? "Gasto" : "Ingreso";
    const monto = (t.tipo === "gasto" ? -t.monto : t.monto).toFixed(2);
    lineas.push([
      t.fecha.toISOString().slice(0, 10),
      tipo,
      celda(t.categoria),
      celda(t.descripcion),
      celda(nombre[t.cuentaId] || "—"),
      monto,
      moneda[t.cuentaId] || monedaPrincipal,
    ].join(","));
  }
  return lineas.join("\n") + "\n";
}

/// Trozos de a lo más [tamanio] caracteres, cortando en saltos de línea.
function partir(texto, tamanio = TAMANIO_PARTE) {
  const partes = [];
  let inicio = 0;
  while (inicio < texto.length) {
    let fin = Math.min(inicio + tamanio, texto.length);
    if (fin < texto.length) {
      const salto = texto.lastIndexOf("\n", fin);
      if (salto > inicio) fin = salto + 1;
    }
    partes.push(texto.slice(inicio, fin));
    inicio = fin;
  }
  return partes;
}

async function crearRespaldo(uid, ahora = new Date()) {
  const db = getFirestore();
  const usuario = db.collection("usuarios").doc(uid);
  const [perfil, cuentasSnap, movSnap] = await Promise.all([
    usuario.get(),
    usuario.collection("cuentas").get(),
    usuario.collection("transacciones").get(),
  ]);
  const cuentas = cuentasSnap.docs.map((d) => ({id: d.id, ...d.data()}));
  const transacciones = movSnap.docs.map((d) => {
    const t = d.data();
    return {...t, fecha: t.fecha && t.fecha.toDate ? t.fecha.toDate() : new Date(0)};
  });
  const csv = generarCsv(transacciones, cuentas, (perfil.data() || {}).moneda || "MXN");
  const partes = partir(csv);

  const mes = claveDia(ahora).slice(0, 7);
  const copias = db.collection("respaldos").doc(uid).collection("copias");
  const ref = copias.doc(mes);
  // Si ya había copia este mes, se reemplaza completa.
  await borrarCopia(ref);
  const lote = db.batch();
  partes.forEach((texto, i) => lote.set(ref.collection("partes").doc(String(i)), {i, csv: texto}));
  lote.set(ref, {
    mes,
    creado: ahora.toISOString(),
    creadoDia: claveDia(ahora),
    movimientos: transacciones.length,
    cuentas: cuentas.length,
    partes: partes.length,
    tamanio: csv.length,
  });
  await lote.commit();

  // Solo las últimas 12.
  const todas = await copias.orderBy("mes", "desc").get();
  for (const vieja of todas.docs.slice(COPIAS_GUARDADAS)) await borrarCopia(vieja.ref);
  return {mes, movimientos: transacciones.length};
}

async function borrarCopia(ref) {
  const partes = await ref.collection("partes").get();
  const lote = getFirestore().batch();
  partes.docs.forEach((p) => lote.delete(p.ref));
  lote.delete(ref);
  await lote.commit();
}

/// Día 1 de cada mes, 5:00 (hora de México): un respaldo por usuario Pro.
exports.respaldoMensual = onSchedule(
  {schedule: "0 5 1 * *", timeZone: "America/Mexico_City", region: "us-central1", timeoutSeconds: 540},
  async () => {
    const pro = await getFirestore().collection("suscripciones").where("plan", "==", "pro").get();
    let ok = 0;
    let fallos = 0;
    for (const doc of pro.docs) {
      // El campo "plan" puede quedar viejo un momento; se confirma.
      if (planVigente(doc.data()) !== "pro") continue;
      try {
        await crearRespaldo(doc.id);
        ok++;
      } catch (error) {
        fallos++;
        logger.error("respaldo_fallo", {mensaje: String(error.message || error)});
      }
    }
    logger.info("respaldo_mensual", {ok, fallos});
  },
);

/// "Hacer un respaldo ahora" (Pro), una vez al día.
exports.respaldoAhora = onCall({region: "us-central1", timeoutSeconds: 120}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Inicia sesión.");
  const uid = request.auth.uid;
  const db = getFirestore();
  const suscripcion = await db.collection("suscripciones").doc(uid).get();
  if (planVigente(suscripcion.data()) !== "pro") {
    throw new HttpsError("permission-denied", "Los respaldos automáticos son parte de NeroMoney Pro.");
  }
  const ultima = await db.collection("respaldos").doc(uid).collection("copias")
      .orderBy("mes", "desc").limit(1).get();
  if (!ultima.empty && ultima.docs[0].data().creadoDia === claveDia(new Date())) {
    throw new HttpsError("resource-exhausted", "Ya hiciste un respaldo hoy. Puedes hacer otro mañana.");
  }
  return crearRespaldo(uid);
});

exports.generarCsv = generarCsv;
exports.partir = partir;
