// Foto del ticket (Pro): la app manda la foto y DeepSeek (modelo con
// visión) devuelve monto, comercio, categoría y fecha para prellenar el
// movimiento. Nada se guarda aquí: el usuario revisa y confirma en la app.

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const {getFirestore} = require("firebase-admin/firestore");
const OpenAI = require("openai");
require("./admin.js");
const {planVigente, mensajeDeLimite} = require("./planes.js");
const {consumirMensajeIA, devolverMensajeIA} = require("./limite_ia.js");

const deepseekApiKey = defineSecret("DEEPSEEK_API_KEY");
// "deepseek-flash" es el modelo vigente con visión (V4.1 Flash).
const MODELO_VISION = "deepseek-flash";

const CATEGORIAS = [
  "Alimentación", "Transporte", "Vivienda", "Servicios",
  "Salud", "Ocio", "Compras", "Educación", "Otro",
];
// ~4 MB de imagen (en base64 ocupa 4/3 más).
const MAX_BASE64 = Math.ceil(4 * 1024 * 1024 * 4 / 3);

/// Valida y deja en forma lo que respondió la IA.
function limpiarTicket(crudo, hoy) {
  let d;
  try {
    d = typeof crudo === "string" ? JSON.parse(crudo) : crudo;
  } catch (_) {
    return null;
  }
  if (!d || typeof d !== "object") return null;
  if (d.esTicket === false) return {esTicket: false};
  const monto = typeof d.monto === "number" ? d.monto : Number(d.monto);
  if (!Number.isFinite(monto) || monto <= 0 || monto > 10_000_000) return {esTicket: false};
  const comercio = typeof d.comercio === "string" ? d.comercio.trim().slice(0, 60) : "";
  const categoria = CATEGORIAS.includes(d.categoria) ? d.categoria : "Otro";
  // Solo fechas reales y no futuras (un ticket no viene del futuro).
  let fecha = null;
  if (typeof d.fecha === "string" && /^\d{4}-\d{2}-\d{2}$/.test(d.fecha)) {
    const f = new Date(`${d.fecha}T12:00:00Z`);
    if (!Number.isNaN(f.getTime()) && d.fecha <= hoy && d.fecha >= "2020-01-01") fecha = d.fecha;
  }
  return {esTicket: true, monto: Math.round(monto * 100) / 100, comercio, categoria, fecha};
}

/// La imagen viene como "data:image/jpeg;base64,..." o solo el base64.
function imagenValida(imagen) {
  if (typeof imagen !== "string" || imagen.length < 100) return null;
  const m = imagen.match(/^data:image\/(jpeg|png|webp|gif);base64,([A-Za-z0-9+/=]+)$/);
  const base64 = m ? m[2] : imagen;
  if (!/^[A-Za-z0-9+/=]+$/.test(base64) || base64.length > MAX_BASE64) return null;
  return `data:image/${m ? m[1] : "jpeg"};base64,${base64}`;
}

exports.leerTicketIA = onCall(
  {secrets: [deepseekApiKey], region: "us-central1", memory: "512MiB"},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Inicia sesión.");
    const uid = request.auth.uid;
    const imagen = imagenValida((request.data || {}).imagen);
    if (!imagen) {
      throw new HttpsError("invalid-argument", "La foto no es válida o pesa más de 4 MB.");
    }
    const suscripcion = await getFirestore().collection("suscripciones").doc(uid).get();
    if (planVigente(suscripcion.data()) !== "pro") {
      throw new HttpsError("permission-denied", "Leer tickets con foto es parte de NeroMoney Pro.");
    }
    // Cuenta como un mensaje de IA (el tope diario de Pro).
    const uso = await consumirMensajeIA(uid);
    if (!uso.permitido) {
      throw new HttpsError("resource-exhausted", mensajeDeLimite(uso.plan, uso.limite));
    }

    const hoy = new Date().toISOString().slice(0, 10);
    const openai = new OpenAI({baseURL: "https://api.deepseek.com", apiKey: deepseekApiKey.value()});
    const inicio = performance.now();
    let resultado = null;
    try {
      const completion = await openai.chat.completions.create({
        model: MODELO_VISION,
        response_format: {type: "json_object"},
        messages: [
          {
            role: "system",
            content:
              "Lees fotos de tickets y recibos de compra para la app de finanzas " +
              `NeroMoney. Hoy es ${hoy}. Responde SOLO un objeto JSON: ` +
              '{"esTicket": true/false, "monto": número total pagado (el TOTAL, ' +
              'no el subtotal ni una línea), "comercio": "nombre del negocio", ' +
              `"categoria": una de ${JSON.stringify(CATEGORIAS)}, ` +
              '"fecha": "YYYY-MM-DD" o null si no se lee}. Si la imagen no es un ' +
              'ticket o no se lee el total, responde {"esTicket": false}. Nunca ' +
              "inventes un monto.",
          },
          {
            role: "user",
            content: [
              {type: "text", text: "Lee este ticket."},
              {type: "image_url", image_url: {url: imagen}},
            ],
          },
        ],
      });
      resultado = limpiarTicket(completion.choices[0].message.content, hoy);
    } catch (error) {
      await devolverMensajeIA(uid).catch(() => {});
      throw error;
    } finally {
      // Solo métricas: nunca la imagen ni lo que se leyó.
      logger.info("leer_ticket", {
        duracionMs: Math.round(performance.now() - inicio),
        resultado: resultado ? (resultado.esTicket ? "ok" : "no_ticket") : "error",
      });
    }
    if (!resultado) {
      throw new HttpsError("unavailable", "No pude leer el ticket. Intenta con otra foto.");
    }
    return resultado;
  },
);

exports.limpiarTicket = limpiarTicket;
exports.imagenValida = imagenValida;
