// Recordatorios de la versión web: la app en el navegador no puede
// programar avisos locales, así que cada 15 minutos esta función revisa a
// quién le toca su recordatorio (según SU zona horaria) y le manda un push
// con Firebase Cloud Messaging a cada navegador que registró.
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
require("./admin.js");

const VENTANA_MINUTOS = 15;
const ZONA_POR_DEFECTO = "America/Mexico_City";

/// Fecha (AAAA-MM-DD) y minutos desde medianoche de `ahora` en `zona`.
function relojLocal(ahora, zona) {
  let partes;
  try {
    partes = new Intl.DateTimeFormat("en-CA", {
      timeZone: zona, year: "numeric", month: "2-digit", day: "2-digit",
      hour: "2-digit", minute: "2-digit", hourCycle: "h23",
    }).formatToParts(ahora);
  } catch (_) {
    return relojLocal(ahora, ZONA_POR_DEFECTO);
  }
  const p = Object.fromEntries(partes.map((x) => [x.type, x.value]));
  return {
    fecha: `${p.year}-${p.month}-${p.day}`,
    minutos: Number(p.hour) * 60 + Number(p.minute),
  };
}

/// Qué recordatorios le tocan a este perfil en esta pasada: los que cayeron
/// en los últimos 15 minutos y no se han mandado hoy.
function recordatoriosPendientes(perfil, ahora) {
  const {fecha, minutos} = relojLocal(ahora, perfil.zonaHoraria || ZONA_POR_DEFECTO);
  const enviados = perfil.recordatoriosEnviados || {};
  const horas = {
    mediodia: Number.isInteger(perfil.horaRecordatorio1) ? perfil.horaRecordatorio1 : 14 * 60,
    noche: Number.isInteger(perfil.horaRecordatorio2) ? perfil.horaRecordatorio2 : 20 * 60,
  };
  return {
    fecha,
    pendientes: Object.entries(horas)
        .filter(([cual, hora]) => {
          const pasados = minutos - hora;
          return pasados >= 0 && pasados < VENTANA_MINUTOS && enviados[cual] !== fecha;
        })
        .map(([cual]) => cual),
  };
}

function textoDe(cual, perfil) {
  const asistente = (perfil.nombreAsistente || "Lucy").toString().slice(0, 40);
  const nombre = (perfil.apodo || "").toString().trim().slice(0, 40);
  return {
    title: `${asistente} 👋`,
    body: cual === "mediodia" ?
      "Te recuerdo registrar tus gastos para llevar tus finanzas bajo control." :
      `Hola${nombre ? ", " + nombre : ""}. ¿Registraste tus gastos hoy? ` +
        "Si no, ¿quieres hacerlo? No te toma más de 10 minutos.",
  };
}

const ERRORES_TOKEN_MUERTO = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

exports.recordatoriosWeb = onSchedule(
  {schedule: "every 15 minutes", region: "us-central1", timeoutSeconds: 120},
  async () => {
    const db = getFirestore();
    const ahora = new Date();
    const snap = await db.collection("usuarios")
        .where("recordatoriosActivados", "==", true)
        .get();
    let enviados = 0;
    for (const doc of snap.docs) {
      const perfil = doc.data();
      const tokens = Array.isArray(perfil.tokensWeb) ?
        perfil.tokensWeb.filter((t) => typeof t === "string" && t) : [];
      if (tokens.length === 0) continue;
      const {fecha, pendientes} = recordatoriosPendientes(perfil, ahora);
      if (pendientes.length === 0) continue;
      // Solo el más reciente: si coinciden los dos, no mandar dos avisos.
      const cual = pendientes[pendientes.length - 1];
      const respuesta = await getMessaging().sendEachForMulticast({
        tokens: tokens.slice(0, 20),
        notification: textoDe(cual, perfil),
        webpush: {notification: {icon: "/icons/Icon-192.png", tag: "nm-" + cual}},
      });
      const muertos = respuesta.responses
          .map((r, i) => (!r.success && ERRORES_TOKEN_MUERTO.has(r.error?.code) ? tokens[i] : null))
          .filter(Boolean);
      const cambios = {};
      for (const p of pendientes) cambios[`recordatoriosEnviados.${p}`] = fecha;
      if (muertos.length) cambios.tokensWeb = FieldValue.arrayRemove(...muertos);
      await doc.ref.update(cambios);
      enviados += respuesta.successCount;
    }
    // Solo conteos: nunca uids, nombres ni tokens.
    logger.info("recordatorios_web", {perfiles: snap.size, enviados});
  },
);

exports._paraPruebas = {relojLocal, recordatoriosPendientes, textoDe};
