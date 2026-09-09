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
const logger = require("firebase-functions/logger");

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
  "Salud", "Ocio", "Compras", "Educación", "Ajuste", "Otro",
];
const CATEGORIAS_INGRESO = [
  "Nómina", "Ventas", "Regalo", "Inversión", "Ajuste", "Pago de tarjeta", "Otro",
];

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
      "'este mes' usa esos periodos tal cual, sin diasAtras. Si el usuario no " +
      "menciona ningún periodo (ej. 'cuánto llevo gastado con mi Rappi " +
      "Card'), usa 'mes' por defecto. Si además menciona una cuenta " +
      "específica (ej. 'con mi Rappi Card', 'de mi tarjeta de Nu'), llena " +
      "cuentaMencionada para que la app calcule el gasto SOLO de esa cuenta.",
    parameters: {
      type: "object",
      properties: {
        periodo: {
          type: "string",
          enum: ["dia", "semana", "mes"],
          description: "El periodo por el que pregunta el usuario (o 'mes' si no dijo ninguno).",
        },
        diasAtras: {
          type: "integer",
          description:
            "Solo aplica si periodo es 'dia': cuántos días atrás de hoy es " +
            "el día por el que preguntan. 0 = hoy, 1 = ayer, 2 = anteayer, " +
            "3 = hace tres días, y así sucesivamente.",
        },
        cuentaMencionada: {
          type: "string",
          description:
            "Solo si preguntó por el gasto de UNA cuenta en particular. Mismo " +
            "criterio que en registrar_transaccion: si se parece a una de " +
            "cuentasDelUsuario devuelve el nombre EXACTO de esa lista; si no, " +
            "el término genérico tal cual. Cadena vacía si preguntó por el " +
            "gasto total (todas las cuentas).",
        },
      },
      required: ["periodo"],
      additionalProperties: false,
    },
  },
};

// Corrige el saldo/disponible de una cuenta a un número EXACTO que el
// usuario acaba de dar (ej. después de contar su efectivo). Nunca hace la
// escritura ella misma: solo entrega cuentaMencionada + nuevoSaldo, y la app
// (AsistenteRepository._actualizarSaldoCuenta) resuelve la cuenta y aplica
// la diferencia como una transacción normal (categoría "Ajuste") — así
// queda en el historial de Movimientos y se puede deshacer, en vez de
// pisar el número sin dejar rastro.
const HERRAMIENTA_ACTUALIZAR_SALDO = {
  type: "function",
  function: {
    name: "actualizar_saldo_cuenta",
    description:
      "Corrige el saldo/disponible de una cuenta a un monto FINAL y exacto " +
      "que el usuario acaba de decir (ej. 'actualiza mi efectivo a 10000', " +
      "'tengo 8500 en mi Nu', 'mi saldo real es 3200 después de contarlo'). " +
      "Solo úsala cuando el usuario da el número TOTAL/final de cuánto tiene " +
      "ahora, nunca cuando describe un gasto o ingreso puntual — eso sigue " +
      "siendo registrar_transaccion (ej. 'gasté 200' NO es un saldo nuevo).",
    parameters: {
      type: "object",
      properties: {
        cuentaMencionada: {
          type: "string",
          description:
            "La cuenta que menciona. Mismo criterio que en " +
            "registrar_transaccion: nombre EXACTO de cuentasDelUsuario si se " +
            "parece, si no el término genérico tal cual.",
        },
        nuevoSaldo: {
          type: "number",
          description: "El nuevo saldo/disponible exacto, sin símbolo de moneda.",
        },
      },
      required: ["cuentaMencionada", "nuevoSaldo"],
      additionalProperties: false,
    },
  },
};

// Pagos/abonos a una tarjeta de crédito. Igual que arriba, solo entrega los
// datos — AsistenteRepository._pagarTarjeta calcula la deuda real
// (limiteCredito - saldoActual) y aplica el pago como un ingreso normal
// (categoría "Pago de tarjeta"), topado a lo que de verdad se debe.
const HERRAMIENTA_PAGAR_TARJETA = {
  type: "function",
  function: {
    name: "pagar_tarjeta_credito",
    description:
      "Registra un pago o abono a una tarjeta de CRÉDITO (ej. 'pagué mi " +
      "Rappi Card y ya no debo nada', 'liquidé toda la deuda de mi tarjeta " +
      "de Nu', 'abone 500 a mi Stori Card', 'pagué toda mi deuda con mi " +
      "tarjeta de crédito'). MUY IMPORTANTE, no la confundas con un gasto: " +
      "'pagué CON mi tarjeta' o 'gasté en mi tarjeta' es una COMPRA (usa " +
      "registrar_transaccion) — el dinero SALE. Esta función es solo cuando " +
      "el dinero ENTRA a la tarjeta (le bajas la deuda): 'pagué A mi " +
      "tarjeta', 'le abone a mi tarjeta', 'liquidé mi tarjeta'.",
    parameters: {
      type: "object",
      properties: {
        cuentaMencionada: {
          type: "string",
          description: "La tarjeta de crédito que menciona (nombre exacto de cuentasDelUsuario si se parece).",
        },
        tipoPago: {
          type: "string",
          enum: ["total", "parcial"],
          description:
            "'total' si dice que pagó/liquidó TODA la deuda, que ya no debe " +
            "nada, o que la dejó en cero. 'parcial' si dio un monto " +
            "específico que abonó, sin decir que quedó saldada del todo.",
        },
        monto: {
          type: "number",
          description: "Solo si tipoPago es 'parcial': cuánto abonó. Omite este campo si tipoPago es 'total'.",
        },
      },
      required: ["cuentaMencionada", "tipoPago"],
      additionalProperties: false,
    },
  },
};

// Estado ACTUAL de una cuenta (cuánto tiene disponible, o cuánto debe si es
// crédito) — distinto de consultar_gasto_periodo, que es un total de FLUJO
// (cuánto se gastó) en un rango de fechas. La app responde con el
// saldoActual/deudaActual real, nunca con algo que el modelo calcule.
const HERRAMIENTA_CONSULTAR_SALDO = {
  type: "function",
  function: {
    name: "consultar_saldo_cuenta",
    description:
      "Consulta el estado ACTUAL de una cuenta: cuánto tiene disponible, o " +
      "cuánto debe si es una tarjeta de crédito (ej. '¿cuánto debo en mi " +
      "Rappi Card?', '¿cuánto tengo disponible en mi Nu?', '¿cuánto tengo " +
      "de efectivo?'). Es el saldo de HOY, no un total gastado en un " +
      "periodo — para 'cuánto he gastado' usa consultar_gasto_periodo.",
    parameters: {
      type: "object",
      properties: {
        cuentaMencionada: {
          type: "string",
          description:
            "La cuenta que pregunta. Mismo criterio que en " +
            "registrar_transaccion: nombre EXACTO de cuentasDelUsuario si se " +
            "parece, si no el término genérico tal cual.",
        },
      },
      required: ["cuentaMencionada"],
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
  "diasAtras para cualquier día puntual, 'mes' si no dijo ningún periodo) " +
  "y deja que la app calcule el número exacto. Si además nombra una cuenta " +
  "en particular (ej. '¿cuánto llevo gastado con mi Rappi Card?'), llena " +
  "cuentaMencionada en esa misma llamada. " +
  "Si el usuario da un monto FINAL y absoluto de cuánto tiene en una cuenta " +
  "ahora mismo — no un gasto ni un ingreso puntual, sino una corrección " +
  "(ej. 'actualiza mi efectivo a 10000', 'tengo 8500 en mi Nu después de " +
  "contarlo', 'mi saldo real es X') — llama a actualizar_saldo_cuenta con " +
  "ese número exacto. NUNCA la confundas con registrar_transaccion: si el " +
  "mensaje describe algo que gastó o le entró (una acción, con un monto que " +
  "se SUMA o RESTA a lo que ya tenía), es una transacción; si da el total " +
  "final que tiene ahora (un monto que REEMPLAZA lo que ya tenía), es un " +
  "ajuste de saldo. " +
  "Si el usuario pregunta por el estado ACTUAL de una cuenta — cuánto " +
  "DEBE, cuánto tiene DISPONIBLE, o cuánto TIENE ahora mismo (ej. '¿cuánto " +
  "debo en mi Rappi Card?', '¿cuánto tengo en mi Nu?', '¿cuánto me queda " +
  "de límite?') — usa consultar_saldo_cuenta. NO la confundas con " +
  "consultar_gasto_periodo: 'cuánto debo/tengo' es el saldo de HOY, " +
  "'cuánto he gastado' es un total sumado en un rango de fechas. " +
  "Para pagos o abonos a una tarjeta de CRÉDITO (ej. 'pagué mi Rappi Card, " +
  "ya no debo nada', 'liquidé mi tarjeta de Nu', 'abone 500 a mi Stori " +
  "Card', 'pagué toda mi deuda con mi tarjeta de crédito'), llama a " +
  "pagar_tarjeta_credito — tipoPago:'total' si dice que quedó en cero o " +
  "saldada del todo, 'parcial' con el monto si dio una cantidad específica " +
  "sin decir que terminó de pagarla. DISTINGUE con cuidado la dirección del " +
  "dinero por la preposición: 'pagué A mi tarjeta' o 'le abone A mi " +
  "tarjeta' es dinero que ENTRA (baja la deuda, usa pagar_tarjeta_credito); " +
  "'pagué CON mi tarjeta' o 'gasté EN mi tarjeta' es dinero que SALE (una " +
  "compra, usa registrar_transaccion) — confundir esta dirección haría que " +
  "una compra real baje la deuda en vez de subirla, así que ante la duda " +
  "prioriza la lectura más natural de la frase completa, no una palabra suelta. " +
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

    const inicioIa = performance.now();
    let completion;
    try {
      completion = await openai.chat.completions.create({
        model: "deepseek-v4-flash", // rápido y barato — perfecto para extracción estructurada
        // Extraer campos no necesita generar una cadena de razonamiento.
        // En el SDK de JavaScript este campo se envía directamente en el body.
        thinking: {type: "disabled"},
        messages: [
          {role: "system", content: MENSAJE_SISTEMA},
          {role: "system", content: contextoTransacciones},
          {role: "system", content: contextoCuentas},
          ...historial,
          {role: "user", content: mensaje},
        ],
        tools: [
          HERRAMIENTA_REGISTRAR_TRANSACCION,
          HERRAMIENTA_CONSULTAR_GASTO,
          HERRAMIENTA_ACTUALIZAR_SALDO,
          HERRAMIENTA_PAGAR_TARJETA,
          HERRAMIENTA_CONSULTAR_SALDO,
        ],
        tool_choice: "auto",
      });
    } finally {
      // Solo métricas operativas: nunca mensajes, argumentos, saldos ni claves.
      logger.info("latencia_deepseek", {
        duracionMs: Math.round(performance.now() - inicioIa),
        modelo: "deepseek-v4-flash",
        razonamiento: "disabled",
        resultado: completion ? "ok" : "error",
        tokensEntrada: completion?.usage?.prompt_tokens ?? null,
        tokensSalida: completion?.usage?.completion_tokens ?? null,
        tokensRazonamiento: completion?.usage?.completion_tokens_details?.reasoning_tokens ?? null,
      });
    }

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
      return {
        tipo: "consulta_gasto",
        periodo: argumentos.periodo,
        diasAtras,
        cuentaMencionada: typeof argumentos.cuentaMencionada === "string" ?
          argumentos.cuentaMencionada : "",
      };
    }

    if (llamadaHerramienta.function.name === "actualizar_saldo_cuenta") {
      const argumentos = JSON.parse(llamadaHerramienta.function.arguments);
      return {
        tipo: "actualizar_saldo",
        cuentaMencionada: typeof argumentos.cuentaMencionada === "string" ?
          argumentos.cuentaMencionada : "",
        nuevoSaldo: argumentos.nuevoSaldo,
      };
    }

    if (llamadaHerramienta.function.name === "pagar_tarjeta_credito") {
      const argumentos = JSON.parse(llamadaHerramienta.function.arguments);
      return {
        tipo: "pagar_tarjeta",
        cuentaMencionada: typeof argumentos.cuentaMencionada === "string" ?
          argumentos.cuentaMencionada : "",
        tipoPago: argumentos.tipoPago === "parcial" ? "parcial" : "total",
        monto: typeof argumentos.monto === "number" ? argumentos.monto : 0,
      };
    }

    if (llamadaHerramienta.function.name === "consultar_saldo_cuenta") {
      const argumentos = JSON.parse(llamadaHerramienta.function.arguments);
      return {
        tipo: "consultar_saldo",
        cuentaMencionada: typeof argumentos.cuentaMencionada === "string" ?
          argumentos.cuentaMencionada : "",
      };
    }

    const datos = JSON.parse(llamadaHerramienta.function.arguments);
    return {tipo: "transaccion_extraida", datos};
  },
);
