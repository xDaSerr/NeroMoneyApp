// Reglas de las membresías de NeroMoney (Gratis / Plus / Pro), sin
// dependencias: todo lo que decide cuántos mensajes de IA tiene alguien y
// cómo se lee una suscripción de Polar vive aquí, para poder probarlo sin
// Firestore ni red.

const crypto = require("node:crypto");

const PLANES = ["gratis", "plus", "pro"];

// Gratis: unos cuantos mensajes al mes para probar a Lucy.
// Plus y Pro: "ilimitado" con un tope diario alto contra abusos.
const LIMITES = {
  gratis: {periodo: "mes", maximo: 15},
  plus: {periodo: "dia", maximo: 100},
  pro: {periodo: "dia", maximo: 300},
};

// past_due = falló un cobro pero Polar sigue reintentando: se conserva el
// acceso hasta que Polar lo dé por perdido (subscription.revoked).
const ESTADOS_CON_ACCESO = new Set(["active", "trialing", "past_due"]);

const ZONA_HORARIA = "America/Mexico_City";

/// "2026-11-13" en la hora de México (el contador diario se reinicia a la
/// medianoche del usuario, no de UTC).
function claveDia(fecha) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: ZONA_HORARIA, year: "numeric", month: "2-digit", day: "2-digit",
  }).format(fecha);
}

function claveMes(fecha) {
  return claveDia(fecha).slice(0, 7);
}

/// El mejor plan entre todas las suscripciones con acceso. Se guardan por
/// id porque un usuario podría tener dos a la vez (ej. compró Pro sin
/// cancelar Plus): si se revoca una, la otra sigue contando.
function planVigente(docSuscripcion) {
  const suscripciones = (docSuscripcion && docSuscripcion.suscripciones) || {};
  let mejor = "gratis";
  for (const s of Object.values(suscripciones)) {
    if (!s || !ESTADOS_CON_ACCESO.has(s.estado)) continue;
    if (PLANES.indexOf(s.plan) > PLANES.indexOf(mejor)) mejor = s.plan;
  }
  return mejor;
}

/// Cuenta un mensaje más si el plan lo permite. Devuelve el documento de
/// uso nuevo (para guardarlo) o permitido:false si ya se llegó al tope.
function registrarUso(usoActual, plan, ahora) {
  const dia = claveDia(ahora);
  const mes = claveMes(ahora);
  const uso = usoActual || {};
  const enDia = uso.dia === dia ? (uso.enDia || 0) : 0;
  const enMes = uso.mes === mes ? (uso.enMes || 0) : 0;
  const limite = LIMITES[plan] || LIMITES.gratis;
  const usados = limite.periodo === "dia" ? enDia : enMes;
  if (usados >= limite.maximo) {
    return {permitido: false, plan, limite};
  }
  return {
    permitido: true,
    plan,
    limite,
    restantes: limite.maximo - usados - 1,
    uso: {dia, enDia: enDia + 1, mes, enMes: enMes + 1},
  };
}

/// Deshace un registrarUso (cuando DeepSeek falló y el mensaje no sirvió).
function devolverUso(uso, ahora) {
  if (!uso) return null;
  const dia = claveDia(ahora);
  const mes = claveMes(ahora);
  return {
    dia: uso.dia,
    enDia: uso.dia === dia ? Math.max(0, (uso.enDia || 0) - 1) : (uso.enDia || 0),
    mes: uso.mes,
    enMes: uso.mes === mes ? Math.max(0, (uso.enMes || 0) - 1) : (uso.enMes || 0),
  };
}

function mensajeDeLimite(plan, limite) {
  if (plan === "gratis") {
    return `Usaste tus ${limite.maximo} mensajes gratis de este mes. Con ` +
      "NeroMoney Plus ($1.50 al mes) hablas conmigo sin límite. Lo " +
      "encuentras en Perfil → Tu plan.";
  }
  return `Llegaste al máximo de ${limite.maximo} mensajes de hoy. Mañana ` +
    "seguimos.";
}

/// ¿Qué plan da este producto de Polar? productos = {plus: {mensual,
/// anual}, pro: {mensual, anual}} con los ids configurados.
function productoAPlan(productoId, productos) {
  if (!productoId) return null;
  for (const plan of ["plus", "pro"]) {
    const ids = productos[plan] || {};
    if (productoId === ids.mensual || productoId === ids.anual) return plan;
  }
  return null;
}

/// Solo se aceptan regresos del checkout a la app propia (nunca a un sitio
/// que mande el cliente: sería una redirección abierta).
function origenPermitido(origen) {
  const porDefecto = "https://neromoneyapp.web.app";
  if (typeof origen !== "string") return porDefecto;
  if (origen === porDefecto || origen === "https://neromoneyapp.firebaseapp.com") {
    return origen;
  }
  if (/^http:\/\/(localhost|127\.0\.0\.1)(:\d{1,5})?$/.test(origen)) return origen;
  return porDefecto;
}

/// Verifica la firma de un webhook de Polar. Los secretos nuevos (desde
/// sept. 2026) siguen Standard Webhooks ("whsec_" + clave en base64); los
/// viejos usan los bytes del secreto completo. Se prueban los dos, igual
/// que el SDK oficial.
function firmaValida({cuerpo, encabezados, secreto, ahoraSeg, toleranciaSeg = 300}) {
  const id = encabezados["webhook-id"];
  const marca = encabezados["webhook-timestamp"];
  const firmas = encabezados["webhook-signature"];
  if (!id || !marca || !firmas || !secreto) return false;
  const segundos = Number(marca);
  if (!Number.isFinite(segundos) || Math.abs(ahoraSeg - segundos) > toleranciaSeg) {
    return false;
  }

  const limpio = secreto.trim();
  const claves = [Buffer.from(limpio, "utf8")];
  if (limpio.startsWith("whsec_")) {
    claves.unshift(Buffer.from(limpio.slice("whsec_".length), "base64"));
  }
  const contenido = `${id}.${marca}.${cuerpo}`;
  const recibidas = String(firmas).split(" ")
      .map((f) => f.split(","))
      .filter(([version, valor]) => version === "v1" && valor)
      .map(([, valor]) => Buffer.from(valor, "base64"));

  for (const clave of claves) {
    const esperada = crypto.createHmac("sha256", clave).update(contenido).digest();
    for (const recibida of recibidas) {
      if (recibida.length === esperada.length && crypto.timingSafeEqual(recibida, esperada)) {
        return true;
      }
    }
  }
  return false;
}

/// Lo que guardamos de una suscripción de Polar (payload del webhook).
function datosDeSuscripcion(sub, productos) {
  return {
    plan: productoAPlan(sub.product_id, productos),
    estado: sub.status || "",
    productoId: sub.product_id || "",
    periodoFin: sub.current_period_end || null,
    cancelaAlFinal: sub.cancel_at_period_end === true,
    modificado: sub.modified_at || sub.created_at || "",
  };
}

/// Uid de Firebase del dueño de la suscripción: lo mandamos como
/// external_customer_id al crear el checkout (y en metadata, de respaldo).
function uidDeSuscripcion(sub) {
  return (sub.customer && sub.customer.external_id) ||
    (sub.metadata && sub.metadata.uid) || null;
}

module.exports = {
  LIMITES,
  claveDia,
  claveMes,
  planVigente,
  registrarUso,
  devolverUso,
  mensajeDeLimite,
  productoAPlan,
  origenPermitido,
  firmaValida,
  datosDeSuscripcion,
  uidDeSuscripcion,
};
