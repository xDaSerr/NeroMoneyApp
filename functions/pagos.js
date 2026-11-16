// Cobro de las membresías con Polar (Plus y Pro).
//
// Flujo:
// 1. La app llama a crearCheckoutPolar → aquí se crea la sesión de pago en
//    Polar con el uid como external_customer_id y se devuelve la URL.
// 2. El usuario paga en la página de Polar y vuelve a la app.
// 3. Polar avisa a webhookPolar; se verifica la firma y se guarda el plan en
//    /suscripciones/{uid}. Ese documento SOLO lo escribe el servidor (ver
//    firestore.rules): nadie puede darse Pro editando su perfil.
// 4. interpretarMensajeIA lee ese plan para decidir el límite de mensajes.

const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret, defineString} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const {getFirestore} = require("firebase-admin/firestore");
require("./admin.js");
const {
  planVigente,
  origenPermitido,
  firmaValida,
  datosDeSuscripcion,
  uidDeSuscripcion,
} = require("./planes.js");

// Secretos: se guardan con `firebase functions:secrets:set NOMBRE`, nunca
// en el repositorio.
const polarToken = defineSecret("POLAR_ACCESS_TOKEN");
const polarWebhookSecret = defineSecret("POLAR_WEBHOOK_SECRET");

// No son secretos (ids de productos), viven en functions/.env.
// POLAR_SERVIDOR = "sandbox" para pruebas, "production" para cobrar de verdad.
const polarServidor = defineString("POLAR_SERVIDOR", {default: "sandbox"});
const productosPolar = {
  plus: {
    mensual: defineString("POLAR_PLUS_MENSUAL", {default: ""}),
    anual: defineString("POLAR_PLUS_ANUAL", {default: ""}),
  },
  pro: {
    mensual: defineString("POLAR_PRO_MENSUAL", {default: ""}),
    anual: defineString("POLAR_PRO_ANUAL", {default: ""}),
  },
};

function productos() {
  return {
    plus: {mensual: productosPolar.plus.mensual.value(), anual: productosPolar.plus.anual.value()},
    pro: {mensual: productosPolar.pro.mensual.value(), anual: productosPolar.pro.anual.value()},
  };
}

function urlApi() {
  return polarServidor.value() === "production" ?
    "https://api.polar.sh" : "https://sandbox-api.polar.sh";
}

async function llamarPolar(ruta, cuerpo) {
  const respuesta = await fetch(`${urlApi()}${ruta}`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${polarToken.value()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(cuerpo),
  });
  if (!respuesta.ok) {
    // Solo el código: el cuerpo puede traer el correo del cliente.
    logger.error("polar_error", {ruta, estado: respuesta.status});
    throw new HttpsError("unavailable", "No pudimos conectar con el sistema de pagos. Intenta de nuevo.");
  }
  return respuesta.json();
}

const suscripcionDoc = (uid) => getFirestore().collection("suscripciones").doc(uid);

/// Crea la página de pago de Polar para Plus o Pro (mensual o anual).
exports.crearCheckoutPolar = onCall(
  {secrets: [polarToken], region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Inicia sesión para suscribirte.");
    }
    const uid = request.auth.uid;
    const datos = request.data || {};
    const plan = datos.plan === "pro" ? "pro" : datos.plan === "plus" ? "plus" : null;
    const periodo = datos.periodo === "anual" ? "anual" : "mensual";
    if (!plan) throw new HttpsError("invalid-argument", "Plan desconocido.");

    const productoId = productos()[plan][periodo];
    if (!productoId) {
      throw new HttpsError("failed-precondition", "Los pagos todavía no están listos. Vuelve pronto.");
    }

    // Quien ya paga cambia de plan o lo cancela desde el portal de Polar,
    // no con un segundo checkout (terminaría con dos cobros).
    const actual = await suscripcionDoc(uid).get();
    if (planVigente(actual.data()) !== "gratis") {
      throw new HttpsError(
          "already-exists",
          "Ya tienes una membresía activa. Cámbiala desde \"Administrar suscripción\".",
      );
    }

    const origen = origenPermitido(datos.origen);
    const cuerpo = {
      products: [productoId],
      external_customer_id: uid,
      success_url: `${origen}/#/planes?pago=ok`,
      return_url: `${origen}/#/planes`,
      metadata: {uid},
    };
    if (request.auth.token && request.auth.token.email) {
      cuerpo.customer_email = request.auth.token.email;
    }
    const checkout = await llamarPolar("/v1/checkouts/", cuerpo);
    return {url: checkout.url};
  },
);

/// Abre el portal de Polar (cambiar de plan, método de pago, cancelar).
exports.abrirPortalPolar = onCall(
  {secrets: [polarToken], region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Inicia sesión para ver tu suscripción.");
    }
    const doc = (await suscripcionDoc(request.auth.uid).get()).data();
    if (!doc || !doc.clientePolarId) {
      throw new HttpsError("failed-precondition", "Todavía no tienes una suscripción.");
    }
    const origen = origenPermitido((request.data || {}).origen);
    const sesion = await llamarPolar("/v1/customer-sessions/", {
      customer_id: doc.clientePolarId,
      return_url: `${origen}/#/planes`,
    });
    return {url: sesion.customer_portal_url};
  },
);

/// Polar avisa aquí cada cambio de una suscripción (alta, renovación,
/// cancelación, cobro fallido, baja).
exports.webhookPolar = onRequest(
  {secrets: [polarWebhookSecret], region: "us-central1"},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("");
      return;
    }
    const cuerpo = req.rawBody ? req.rawBody.toString("utf8") : "";
    const valida = firmaValida({
      cuerpo,
      encabezados: req.headers,
      secreto: polarWebhookSecret.value(),
      ahoraSeg: Math.floor(Date.now() / 1000),
    });
    if (!valida) {
      logger.warn("polar_webhook_firma_invalida");
      res.status(403).send("");
      return;
    }

    const evento = JSON.parse(cuerpo);
    if (!String(evento.type || "").startsWith("subscription.")) {
      res.status(202).send("");
      return;
    }

    const sub = evento.data || {};
    const uid = uidDeSuscripcion(sub);
    const registro = datosDeSuscripcion(sub, productos());
    if (!uid || !sub.id || !registro.plan) {
      // Sin uid o con un producto que no es de NeroMoney: nada que hacer.
      logger.warn("polar_webhook_sin_destino", {tipo: evento.type, tieneUid: !!uid, plan: registro.plan});
      res.status(202).send("");
      return;
    }

    const ref = suscripcionDoc(uid);
    await getFirestore().runTransaction(async (tx) => {
      const actual = (await tx.get(ref)).data() || {};
      const suscripciones = {...(actual.suscripciones || {})};
      const previa = suscripciones[sub.id];
      // Los webhooks pueden llegar desordenados: no pisar algo más nuevo.
      if (previa && previa.modificado && previa.modificado > registro.modificado) return;
      suscripciones[sub.id] = registro;
      const nuevo = {suscripciones};
      tx.set(ref, {
        suscripciones,
        plan: planVigente(nuevo),
        clientePolarId: sub.customer_id || actual.clientePolarId || null,
        actualizado: new Date(),
      }, {merge: true});
    });

    logger.info("polar_webhook", {tipo: evento.type, estado: registro.estado, plan: registro.plan});
    res.status(202).send("");
  },
);
