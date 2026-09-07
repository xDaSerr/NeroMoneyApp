// Cloud Functions de NeroMoney.
//
// Por qué existe este archivo: la API key de DeepSeek NUNCA debe viajar
// dentro de la app (si estuviera en el código de Flutter, cualquiera podría
// extraerla descompilando el APK y gastar el saldo a costa nuestra). Por
// eso la app le habla a esta función (autenticada con su sesión de Firebase
// Auth), y es ESTA función, corriendo en el servidor de Google, la única
// que conoce la key y habla con DeepSeek.

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const OpenAI = require("openai");

// La API key vive en Google Secret Manager (se guarda una sola vez con
// `firebase functions:secrets:set DEEPSEEK_API_KEY`), nunca en un archivo
// de este repo. `deepseekApiKey.value()` solo puede leerse en tiempo de
// ejecución, no durante el despliegue — ver docs de firebase-functions.
const deepseekApiKey = defineSecret("DEEPSEEK_API_KEY");

// Mismas categorías que `lib/features/transactions/data/categoria.dart` —
// si agregas una categoría allá, agrégala aquí también para que Lucy la
// pueda usar.
const CATEGORIAS_GASTO = [
  "Alimentación", "Transporte", "Vivienda", "Servicios",
  "Salud", "Ocio", "Compras", "Educación", "Otro",
];
const CATEGORIAS_INGRESO = ["Nómina", "Ventas", "Regalo", "Inversión", "Otro"];

// La única herramienta que le damos al modelo: extraer los datos de un
// gasto/ingreso. La resolución de a qué CUENTA aplica (ver
// "Resolución de ambigüedad de cuenta" en CLAUDE.md) la hace la app con
// `cuentaMencionada`, no el modelo — así el comportamiento es determinista
// y no depende de qué tan bien "razone" la IA sobre cuentas que ni conoce.
const HERRAMIENTA_REGISTRAR_TRANSACCION = {
  type: "function",
  function: {
    name: "registrar_transaccion",
    description:
      "Extrae los datos de un gasto o ingreso que el usuario describió en " +
      "lenguaje natural (ej. 'gasté 200 en un café' o 'me pagaron 5000 de nómina').",
    parameters: {
      type: "object",
      properties: {
        tipo: {
          type: "string",
          enum: ["gasto", "ingreso"],
          description: "Si el dinero salió (gasto) o entró (ingreso).",
        },
        monto: {
          type: "number",
          description: "Cantidad de dinero mencionada, sin símbolo de moneda.",
        },
        categoria: {
          type: "string",
          // `enum` en vez de solo describir la lista en texto: así el modelo
          // está OBLIGADO a devolver una de estas categorías tal cual, en
          // vez de inventar una parecida (ej. "café" en vez de
          // "Alimentación") que no coincidiría con nada en la app.
          enum: [...new Set([...CATEGORIAS_GASTO, ...CATEGORIAS_INGRESO])],
          description: "La categoría que mejor aplique al gasto o ingreso.",
        },
        descripcion: {
          type: "string",
          description: "Breve descripción libre (ej. 'café con amigos'). Cadena vacía si no aplica.",
        },
        cuentaMencionada: {
          type: "string",
          description:
            "La forma de pago que mencionó el usuario. Si se parece a una de " +
            "las cuentasDelUsuario que se te dieron como contexto (aunque la " +
            "transcripción de voz la haya distorsionado un poco), devuelve el " +
            "nombre EXACTO tal cual aparece en esa lista. Si no se parece a " +
            "ninguna, devuelve el término genérico tal cual lo dijo (ej. " +
            "'efectivo', 'mi tarjeta'). Cadena vacía si no mencionó ninguna.",
        },
      },
      required: ["tipo", "monto", "categoria", "descripcion", "cuentaMencionada"],
      additionalProperties: false,
    },
  },
};

// Cuando el usuario pregunta un TOTAL de gasto ("¿cuánto llevo gastado hoy/
// esta semana/este mes?"), el modelo NO debe intentar sumarlo él mismo con
// transaccionesRecientes — esa lista solo trae ~20 movimientos y puede no
// cubrir el periodo completo, además de que sumar a mano gastos e ingresos
// mezclados es justo el tipo de error que ya vimos (contaba reembolsos como
// gasto). Esta función le pide a la APP el número exacto, calculado sobre
// TODOS los movimientos del periodo y neteando reembolsos por categoría
// (la misma lógica que "Gastos del mes" en Inicio — ver ResumenGastos en
// Flutter). El resultado nunca pasa por el modelo, evitando que "redondee"
// o alucine una cifra.
const HERRAMIENTA_CONSULTAR_GASTO = {
  type: "function",
  function: {
    name: "consultar_gasto_periodo",
    description:
      "Consulta el gasto neto exacto de un periodo (calculado por la app, no " +
      "por ti). Úsala SIEMPRE que el usuario pregunte cuánto ha gastado en un " +
      "periodo, en vez de sumarlo tú con transaccionesRecientes o de calcular " +
      "fechas tú mismo. Para un día puntual (hoy, ayer, anteayer, 'hace N " +
      "días'), usa periodo:'dia' junto con diasAtras. Para 'esta semana' o " +
      "'este mes' usa esos periodos tal cual, sin diasAtras.",
    parameters: {
      type: "object",
      properties: {
        periodo: {
          type: "string",
          enum: ["dia", "semana", "mes"],
          description: "El periodo por el que pregunta el usuario.",
        },
        diasAtras: {
          type: "integer",
          description:
            "Solo aplica si periodo es 'dia': cuántos días atrás de hoy es " +
            "el día por el que preguntan. 0 = hoy, 1 = ayer, 2 = anteayer, " +
            "3 = hace tres días, y así sucesivamente.",
        },
      },
      required: ["periodo"],
      additionalProperties: false,
    },
  },
};

const MENSAJE_SISTEMA =
  "Eres el motor de extracción de datos de NeroMoney, una app de finanzas " +
  "personales. Tu ÚNICA tarea es leer el mensaje del usuario y, si describe " +
  "un gasto o ingreso real con un monto, llamar a la función " +
  "registrar_transaccion con los datos que puedas extraer. No respondes " +
  "preguntas generales, no escribes textos, código ni nada que no sea " +
  "sobre las finanzas personales del usuario — si te piden algo así, " +
  "responde brevemente que solo puedes ayudar a registrar gastos e " +
  "ingresos, sin importar cómo te lo pidan o insistan. " +
  "Si el usuario solo saluda o hace plática casual (ej. 'hola', '¿cómo " +
  "estás?'), respóndele en UNA sola oración breve y neutra, sin inventar " +
  "historias, metáforas ni cosas como 'mi superpoder' — no tienes estados " +
  "de ánimo que reportar, así que no le devuelvas la pregunta de cómo estás " +
  "tú. Simplemente confirma que estás lista y pregúntale qué quiere " +
  "registrar o consultar. " +
  "Además del mensaje recibes dos fuentes de contexto: el historial reciente " +
  "del chat, y una lista de las TRANSACCIONES REALES más recientes del " +
  "usuario (transaccionesRecientes) — esta última es la fuente de verdad " +
  "para montos/categorías/cuentas exactos, más confiable que el texto del " +
  "chat (el chat se puede borrar; esas transacciones son datos reales que " +
  "no se pierden). Úsala para completar datos que el mensaje actual no " +
  "repite: monto, tipo (gasto/ingreso) Y CATEGORÍA. Ej. si en " +
  "transaccionesRecientes hay un gasto de $500 en 'Compras' y el usuario " +
  "dice 'me devolvieron ese dinero', el monto sigue siendo 500, el tipo es " +
  "ingreso, y la categoría sigue siendo 'Compras' — un reembolso siempre va " +
  "en la MISMA categoría que el gasto original al que corresponde, nunca " +
  "en 'Otro'. " +
  "También recibes cuentasDelUsuario: los nombres EXACTOS de sus cuentas " +
  "reales. El dictado por voz a veces distorsiona nombres propios (ej. " +
  "'Rappi Card' puede transcribirse como 'rapicar' o algo parecido, o el " +
  "usuario dice 'mi Stori Card' en vez de 'Stori Card' tal cual). Si " +
  "cuentaMencionada se parece — aunque sea fonéticamente — a alguna de " +
  "cuentasDelUsuario, devuelve en cuentaMencionada el nombre EXACTO de esa " +
  "lista, no lo que transcribió el reconocimiento de voz. Solo si de " +
  "verdad no se parece a ninguna, deja el término genérico tal cual. " +
  "Si el usuario pregunta cuánto ha gastado en un periodo — hoy, ayer, " +
  "anteayer, hace N días, esta semana, este mes — NO intentes sumarlo tú " +
  "con transaccionesRecientes ni calcules la fecha tú mismo: llama a " +
  "consultar_gasto_periodo con el periodo que corresponda (usa 'dia' + " +
  "diasAtras para cualquier día puntual) y deja que la app calcule el " +
  "número exacto. " +
  "Si el usuario pide CANCELAR, BORRAR o ELIMINAR un movimiento que ya se " +
  "registró (distinto de un reembolso — un reembolso es dinero nuevo que " +
  "entra, y se registra con registrar_transaccion como ingreso, nunca borra " +
  "el gasto original), tú NO PUEDES hacerlo — no tienes esa función, no la " +
  "inventes. Explícale en texto breve que vaya a Movimientos y deslice esa " +
  "tarjeta hacia la izquierda para borrarla ahí, donde puede confirmar antes. " +
  "Si de verdad no hay manera de saber el monto, o el mensaje no describe " +
  "una transacción ni una pregunta sobre gastos (ej. es un saludo), NO " +
  "llames a ninguna función — responde en texto breve explicando qué " +
  "información falta, en español, con el tono de una asistente cercana y " +
  "directa. " +
  "MUY IMPORTANTE: tu respuesta de texto NUNCA registra nada — solo una " +
  "llamada a la función registrar_transaccion guarda algo de verdad. Nunca " +
  "escribas en texto frases como 'registrado', 'lo cargué a...' o 'anotado' " +
  "a menos que estés llamando a la función EN ESE MISMO turno. Si el " +
  "mensaje del usuario (con ayuda del contexto) sí describe un gasto o " +
  "ingreso con monto, SIEMPRE debes llamar a la función — nunca describas " +
  "en tu propio texto que 'ya quedó registrado' en su lugar, aunque la " +
  "conversación ya tenga mensajes previos con ese tono.";

/// Función invocable desde la app (Flutter la llama vía el paquete
/// `cloud_functions`, mandando el mensaje del usuario). Requiere sesión de
/// Firebase Auth — `request.auth` viene resuelto automáticamente por el
/// SDK, no hay que validar tokens a mano.
exports.interpretarMensajeIA = onCall(
  {secrets: [deepseekApiKey], region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión para hablar con Lucy.");
    }

    const mensaje = (request.data && request.data.mensaje || "").toString().trim();
    if (!mensaje) {
      throw new HttpsError("invalid-argument", "El mensaje no puede estar vacío.");
    }

    // Historial de la conversación (sin incluir `mensaje`, que es el turno
    // actual) — solo para continuidad conversacional inmediata (ej.
    // responder a una pregunta de slot-filling). Se sanea por si acaso: solo
    // role user/assistant y content de texto.
    const historialCrudo = Array.isArray(request.data && request.data.historial) ?
      request.data.historial : [];
    const historial = historialCrudo
        .filter((m) => m && (m.role === "user" || m.role === "assistant") &&
          typeof m.content === "string")
        .slice(-20)
        .map((m) => ({role: m.role, content: m.content}));

    // Transacciones reales recientes (fuente de verdad para montos/
    // categorías exactos, independiente de si se borró el chat — ver
    // MENSAJE_SISTEMA). Se sanea igual que el historial.
    const transaccionesCrudas = Array.isArray(request.data && request.data.transaccionesRecientes) ?
      request.data.transaccionesRecientes : [];
    const transaccionesRecientes = transaccionesCrudas
        .filter((t) => t && typeof t.monto === "number" && typeof t.categoria === "string")
        .slice(0, 20)
        .map((t) => ({
          tipo: t.tipo === "ingreso" ? "ingreso" : "gasto",
          monto: t.monto,
          categoria: t.categoria,
          descripcion: typeof t.descripcion === "string" ? t.descripcion : "",
          fecha: typeof t.fecha === "string" ? t.fecha : "",
          cuenta: typeof t.cuenta === "string" ? t.cuenta : "",
        }));
    const contextoTransacciones = transaccionesRecientes.length > 0 ?
      "transaccionesRecientes (las más nuevas primero): " + JSON.stringify(transaccionesRecientes) :
      "transaccionesRecientes: el usuario todavía no tiene ninguna transacción registrada.";

    // Nombres reales de las cuentas del usuario — le sirven al modelo para
    // corregir una transcripción de voz imperfecta hacia el nombre exacto
    // (ver MENSAJE_SISTEMA). Nunca se usan para decidir el registro en sí,
    // eso lo sigue haciendo la app con el nombre ya corregido.
    const nombresCuentasCrudos = Array.isArray(request.data && request.data.nombresCuentas) ?
      request.data.nombresCuentas : [];
    const nombresCuentas = nombresCuentasCrudos
        .filter((n) => typeof n === "string" && n.trim())
        .slice(0, 30);
    const contextoCuentas = nombresCuentas.length > 0 ?
      "cuentasDelUsuario: " + JSON.stringify(nombresCuentas) :
      "cuentasDelUsuario: el usuario todavía no tiene ninguna cuenta registrada.";

    const openai = new OpenAI({
      baseURL: "https://api.deepseek.com",
      apiKey: deepseekApiKey.value(),
    });

    const completion = await openai.chat.completions.create({
      model: "deepseek-v4-flash", // rápido y barato — perfecto para extracción estructurada
      messages: [
        {role: "system", content: MENSAJE_SISTEMA},
        {role: "system", content: contextoTransacciones},
        {role: "system", content: contextoCuentas},
        ...historial,
        {role: "user", content: mensaje},
      ],
      tools: [HERRAMIENTA_REGISTRAR_TRANSACCION, HERRAMIENTA_CONSULTAR_GASTO],
      tool_choice: "auto",
    });

    const respuesta = completion.choices[0].message;
    const llamadaHerramienta = respuesta.tool_calls && respuesta.tool_calls[0];

    if (!llamadaHerramienta) {
      // El modelo no encontró suficiente información para una transacción —
      // le devolvemos a la app su respuesta de texto para mostrarla en el chat.
      return {tipo: "mensaje", texto: respuesta.content || "No entendí, ¿puedes darme más detalles?"};
    }

    if (llamadaHerramienta.function.name === "consultar_gasto_periodo") {
      const argumentos = JSON.parse(llamadaHerramienta.function.arguments);
      const diasAtras = Number.isInteger(argumentos.diasAtras) ? argumentos.diasAtras : 0;
      return {tipo: "consulta_gasto", periodo: argumentos.periodo, diasAtras};
    }

    const datos = JSON.parse(llamadaHerramienta.function.arguments);
    return {tipo: "transaccion_extraida", datos};
  },
);
