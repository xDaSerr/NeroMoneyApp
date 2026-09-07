# NeroMoneyApp

App de finanzas personales (Android, con iOS planeado a futuro) con un asistente de IA conversacional configurable por el usuario (nombre por defecto: **Lucy**) que registra gastos/ingresos por texto o voz en lenguaje natural.

## Estructura del repo

Esta carpeta raíz (`NeroMoneyApp/`) contiene dos proyectos hermanos:

- `neromoney_app/` — la app Flutter (el código real).
- `stitch_neromoney_ai_finance_app/` — las 18 pantallas de referencia + logo, generadas con Google Stitch. Cada subcarpeta es una pantalla (`code.html` + `screen.png`). La guía de estilo completa vive en `stitch_neromoney_ai_finance_app/obsidian_cyber_glass/DESIGN.md`.

Todos los comandos de Flutter (`flutter run`, `flutter test`, `flutter analyze`, `flutter pub get`) se ejecutan dentro de `neromoney_app/`.

**Pendientes conocidos en las pantallas de Stitch** (revisar al traducir a Flutter, si no se ha hecho ya): varias pantallas (Cuentas, Gastos incompletos, MSI) traían un título de header pegado incorrecto ("Account Access"); la barra de navegación inferior no era consistente entre pantallas — ya se resolvió en el código con 5 pestañas fijas (ver abajo).

## Stack

- **Frontend:** Flutter (Dart), Material 3.
- **Estado:** `flutter_riverpod` (v3).
- **Navegación:** `go_router` con `StatefulShellRoute.indexedStack` para las 5 pestañas principales (cada una mantiene su propio historial de navegación).
- **Auth:** Firebase Authentication (email/contraseña + Google Sign-In).
- **Datos:** Cloud Firestore (offline-first automático), todo bajo `usuarios/{uid}/...`, ligado al UID de Firebase Auth. Reglas en `firestore.rules` con deny-by-default fuera de esa ruta.
- **Asistente IA:** DeepSeek API (`deepseek-v4-flash`, chat completions con function calling) — la app **nunca** habla directo con DeepSeek. Le habla a una Cloud Function propia (`functions/index.js`, función `interpretarMensajeIA`) que guarda la API key en Secret Manager y valida la sesión de Firebase Auth antes de reenviar la llamada. Esto evita que la key quede expuesta dentro del APK (ver "Backend de IA" abajo). La pestaña `/assistant` (chat con Lucy) ya está construida — ver "Estado actual de implementación".
- **Voz:** `speech_to_text` (dictado) y `flutter_tts` (respuesta hablada) — ya integrados en `AssistantChatScreen`. Decisión explícita del usuario: Lucy solo responde en voz cuando el usuario le dictó esa pregunta por micrófono (no hay un interruptor de "modo voz" aparte) — un mensaje escrito a mano siempre responde en silencio. El micrófono es de **mantener presionado** (`onTapDown`/`onTapUp`/`onTapCancel`, no un interruptor de tap) — empieza a escuchar al presionar, transcribe en vivo, y manda el mensaje solo al soltar (`_voz.stop()` fuerza el `finalResult` de `speech_to_text`). Antes de leer una respuesta, `_textoParaVoz` reemplaza "$1,234.56" por "1,234.56 {moneda hablada}" (`monedaHablada` en `currency_picker.dart`, según `PerfilUsuario.moneda`) — un lector de texto a voz interpreta "$" como dólares sin importar la moneda real configurada, si no se hace este reemplazo.
- **Animaciones:** `flutter_animate` para micro-interacciones; Rive planeado para animaciones "hero" (ej. avatar del asistente) — aún no agregado.
- Proyecto Firebase: `neromoneyapp` (ver `.firebaserc` / `firebase.json`).

## Navegación (actualizada — decisión explícita del usuario)

**Silencio al dictar:** no se trata como un fallo de registro. `EstadoDictado.sinVoz` muestra "No te escuché" durante 3 segundos, no bloquea el botón y se descarta al volver a tocar el avatar. Si el segundo gesto empieza mientras termina o se procesa el anterior, la barra conserva esa pulsación y activa la nueva escucha cuando queda libre, solo si el dedo sigue pulsando. Soltar o cancelar el gesto pendiente no interrumpe la operación anterior ni deja una escucha diferida. En el chat (`indiceActual == 2`) se desactivan el dictado y la animación de voz del avatar de navegación. El temporizador se cancela al iniciar otra acción o destruir el controlador. Los errores de permisos y de resultado incierto no se cierran solos. El controlador es el único que cancela la escucha nativa (`cancelOnError: false` en el plugin), para que una cancelación duplicada no interfiera con el siguiente intento.

**Dictado global desde la barra (implementado):** `core/widgets/barra_flotante.dart` dibuja una píldora recta en reposo, con el avatar dentro; la elevación central aparece solo al mantener pulsado. Mantener pulsado el avatar inicia el micrófono desde Inicio, Movimientos, Cuentas o Perfil; dentro del chat se usa únicamente su propio botón de micrófono; solo el centro y el avatar crecen (280 ms), los extremos permanecen fijos. Soltar restaura la forma y envía el dictado una sola vez. Un toque corto abre el chat. El nombre queda accesible por `Semantics`; mantener pulsado ya no muestra un tooltip. Se respetan los colores personalizados y la preferencia de reducir movimiento. `AsistenteAvatar` conserva su `ImageProvider` y solo decodifica Base64 cuando cambia la foto (`initState`/`didUpdateWidget`, con `gaplessPlayback`); decodificar dentro de `build` causaba parpadeos en la barra y el chat durante el dictado.

`ControladorAsistente` (`features/assistant/data/`) comparte micrófono y bloqueo de envíos entre la barra y el chat. El plugin nativo se inicializa bajo demanda desde `controlador_asistente_provider.dart`. Cancelar, salir de la app o soltar durante la petición de permisos no envía nada. La respuesta, transcripción y chips de cuenta aparecen en `PanelVozAsistente` sobre la pestaña actual. La marca "Registrado" viene del mensaje persistido por el repositorio. Las entradas de voz usan `iaVoz` y reciben respuesta hablada con la moneda configurada; las escritas permanecen silenciosas. El controlador reemplaza el manejo de `SpeechToText`/`FlutterTts` que antes vivía dentro de `AssistantChatScreen`.

Las 5 pestañas de la barra inferior son: **Inicio, Movs, [asistente], Cuentas, Perfil**. "Reportes" ya NO es una pestaña — se movió dentro de Perfil (un ítem de menú que hace `context.push('/reports')`); "Cuentas" tomó su lugar en la barra inferior. `/accounts` vive dentro del `StatefulShellRoute` (antes era una ruta suelta), con `/accounts/detalle` anidado debajo para que "atrás" regrese a la lista sin salir de la pestaña. Cualquier enlace a Cuentas desde otra pestaña debe usar `context.go('/accounts')` (cambia de pestaña), no `.push()`.

**La pestaña del asistente NO lleva texto** (`app_shell.dart`) — decisión explícita del usuario tras notar que un texto fijo "Lucy IA" quedaba mal en cuanto alguien le ponía otro nombre a su asistente. En su lugar muestra `AsistenteAvatar` (la foto elegida por el usuario, o el ícono de la app si no eligió ninguna); el nombre sigue disponible como `tooltip` al mantener presionado. Si se vuelve a necesitar texto ahí, recordar que `NavigationDestination.label` siempre se renderiza — no hay forma de ocultarlo solo para un destino sin pasar `label: ''`.

## Arquitectura de carpetas (`neromoney_app/lib/`)

**Barra flotante:** `AppShell` usa `extendBody: true`. En las pestañas, el área desplazable debe llegar hasta el fondo (`SafeArea(bottom: false)` cuando se usa `SafeArea`), con `espacioParaBarraFlotante(context)` como padding DENTRO del scroll. Ese helper usa `viewPadding.bottom`, porque Flutter reemplaza `padding.bottom` por la altura de la navegación al extender el cuerpo; usar ese valor duplicaba el margen. El margen cubre también el avatar y desaparece cuando el teclado reduce el cuerpo. En el chat, la entrada conserva su separación explícita sin volver a sumar el SafeArea inferior.

```
core/
  router/    → app_router.dart (todas las rutas), app_shell.dart (shell de 5 tabs), go_router_refresh_stream.dart
  theme/     → app_colors.dart, app_text_styles.dart, app_theme.dart (Obsidian Cyber-Glass)
  widgets/   → widgets compartidos (glass_card, gradient_button, placeholder_screen)
features/
  auth/         → login, registro, recuperar contraseña + auth_repository
  onboarding/   → flujo de onboarding + perfil_repository / perfil_usuario
  accounts/     → cuentas ("bolsillos" de dinero) + repositorio + providers
  transactions/ → modelo Transaccion + repositorio + providers (sin UI propia aún, se consume desde home/asistente)
  home/         → dashboard
  profile/      → perfil/configuración
```

Patrón por feature: `data/` (modelos + repositorio Firestore) → `providers/` (Riverpod, exponen streams/estado a la UI) → pantallas en la raíz del feature. Seguir este patrón al agregar features nuevas (ej. `assistant/`, `movements/`, `reports/`).

Convención de nombres: el dominio (clases, campos de Firestore, enums) está en **español** (`Cuenta`, `Transaccion`, `TipoCuenta`, `saldoActual`, `esPredeterminada`); los comentarios en el código también están en español y explican el *por qué*, no el qué. Mantener esa convención en código nuevo.

**Comentarios de navegación en pantallas:** además de explicar el *por qué*, cada botón/campo/sección interactiva relevante de una pantalla lleva un comentario corto tipo `// --- Botón "X": hace Y ---` justo antes del widget. Esto es a propósito para que sea fácil ubicar "dónde está el botón de tal cosa" sin tener que leer todo el archivo. Seguir esta convención en pantallas nuevas (ej. al construir `/assistant` y `/reports`).

## Estado actual de implementación

Ya construido: login/registro/recuperar contraseña, onboarding (moneda + nombre del asistente), CRUD de cuentas (crear/editar/eliminar, con edición manual de disponible/límite para reconciliar tarjetas de crédito), registro manual de movimientos, perfil, ruteo completo con redirect por sesión/onboarding.

**Inicio (Home)** sigue la estructura de la pantalla de Inicio del Stitch con datos reales: saludo con nombre real + avatar, patrimonio total, accesos rápidos (Ingreso/Gasto abren alta manual preseleccionada; Transferir avisa que no existe aún; Analizar va a Reportes), cuadrícula de cuentas, resumen de gastos del mes por categoría (calculado de transacciones reales), y vista previa de últimos movimientos. Se omiten a propósito el estado "Lucy conectada", la alerta de Lucy y el botón de voz — dependen del asistente de IA, que aún no existe; se agregan cuando ese sí exista de verdad.

**`/assistant` (chat con Lucy) ya está construido** — `AssistantChatScreen` en `features/assistant/`. Manda el mensaje al Cloud Function, resuelve la cuenta con el algoritmo de 4 niveles (en Dart, ver `AsistenteRepository`), y registra la transacción real con `TransaccionesRepository`. Guarda el historial (`usuarios/{uid}/mensajesAsistente/`) y el borrador pendiente (`usuarios/{uid}/estadoAsistente/borrador`) en Firestore.

Simplificado a propósito en esta v1 (documentado para no confundirlo con bugs, y como lista de mejoras futuras):
- Nivel 3 de ambigüedad (varias cuentas del mismo tipo) no tiene todavía un botón de "Cambiar" de un toque — el usuario tiene que decirlo de nuevo por chat.
- La confirmación es un mensaje de texto simple, no la tarjeta rica del Stitch (con barra de progreso, "Modificar"/"Deshacer") — esa requiere una pantalla de "editar transacción" que todavía no existe.
- Sin dictado por voz ni respuestas a preguntas analíticas ("¿cuánto he gastado hoy?") — el backend hoy solo extrae transacciones, responder preguntas es una capacidad distinta (necesitaría su propia tool en `functions/index.js` que consulte Firestore).

**Personalización del asistente (foto y nombre) — `/personalizar-asistente`:** pantalla aparte (`PersonalizarAsistenteScreen`, en `features/profile/`), a la que se llega desde un ítem de menú en Perfil — **nunca** desde el onboarding, que a propósito solo pide el nombre (decisión explícita del usuario: personalizar la foto es algo que se hace cuando uno quiere, no un paso obligatorio al registrarse). Inspirada en el mockup de Stitch `6._onboarding_2_3_asistente_ia`, pero sin su sección de "Tono de asistencia" — esa personalidad configurable no existe de verdad en el backend de IA, y no se fabrican controles que no hagan nada.
- La foto se guarda como Base64 directo en `usuarios/{uid}.avatarAsistenteBase64` (no en Firebase Storage): es una sola imagen pequeña por usuario, así que evita depender de un servicio y unas reglas de seguridad aparte. Se redimensiona/comprime al elegirla (`ImagePicker.pickImage(maxWidth: 320, maxHeight: 320, imageQuality: 70)`) para que quepa cómoda en el límite de 1 MiB por documento de Firestore.
- Quitar la foto (volver al ícono de la app) usa `PerfilRepository.actualizarAvatarAsistente(null)`, que hace `FieldValue.delete()` sobre el campo — un `set(merge:true)` normal solo sabe agregar/reemplazar campos, nunca borrarlos, así que ese caso necesita su propio método (mismo tipo de problema, sin resolver todavía, que tienen `ultimos4Digitos`/`colorPersonalizado` de `Cuenta` al editarlos vía `.update()` en `CuentasRepository.actualizarCuenta`).
- `AsistenteAvatar` (`core/widgets/`) es el único widget que sabe pintar "la cara" del asistente (foto o ícono de la app por defecto) — se usa en la pestaña inferior, el encabezado del chat, las burbujas de Lucy y el estado vacío del chat, para que cambiar la foto se refleje en todos lados a la vez.
- **Pestaña del asistente en la barra inferior:** a propósito es la única SIN texto (ver "Navegación" arriba) y notablemente más grande que las demás, con un anillo degradado y brillo alrededor (`AnilloAsistente`, `core/widgets/`) — pedido explícito del usuario con una referencia visual de Stitch. Los 2 colores del degradado son elegibles por el usuario (`colorAnilloInicio`/`colorAnilloFin` en `PerfilUsuario`, ARGB) desde `PersonalizarAsistenteScreen`, con una paleta curada de combinaciones en `paleta_anillos_asistente.dart` (no un selector de color libre — mismo criterio que `paletaColoresCuentas` para las cuentas). Si el usuario nunca abrió esa pantalla, ambos quedan `null` y `AnilloAsistente` usa el degradado por defecto (violeta→cian) — a diferencia de la foto, este par NO necesita un método de borrado especial (`FieldValue.delete()`): una vez elegido, siempre es un valor real, así que viaja por el `copyWith`/`guardarPerfil` normal.

Pendiente: **`/reports`** — hoy es un `PlaceholderScreen` en `app_router.dart`. `/movements` ya tiene su historial real (`MovementsScreen`, con borrado deslizando hacia la izquierda + confirmación — revierte el efecto en el saldo), solo le falta agregar filtros.

Al implementar estas, revisar la pantalla correspondiente ya diseñada en `stitch_neromoney_ai_finance_app/`.

## Modelo de datos (Firestore, bajo `usuarios/{uid}/`)

- **`usuarios/{uid}` (doc raíz):** `PerfilUsuario` — moneda (código ISO, se elige una sola vez, sin conversión multi-moneda), nombre del asistente, flag de onboarding completado.
- **`cuentas/{id}`:** `Cuenta` — nombre, `TipoCuenta` (efectivo/débito/crédito/vale/otro), `saldoActual` (obligatorio), y solo si es crédito: `limiteCredito` (obligatorio para crédito) + día de corte/día de pago (siempre opcionales, nunca forzados).
- **`transacciones/{id}`:** `Transaccion` — monto, `TipoTransaccion` (gasto/ingreso), categoría, descripción, `cuentaId` (a qué cuenta afecta), fecha, `OrigenTransaccion` (manual/iaTexto/iaVoz).

**Un gasto nunca puede dejar `saldoActual` en negativo** (`SaldoInsuficienteException`, en `transacciones_repository.dart` — se lanza dentro de la misma `runTransaction`, así que no se llega a escribir nada). Aplica igual a efectivo/débito/vale/otro (no tienes ese dinero) que a una tarjeta de crédito (te pasarías del límite disponible). Tanto el alta manual (`AddTransactionScreen`) como Lucy pasan por este mismo repositorio, así que la regla nunca se puede saltar por accidente desde ningún punto de entrada nuevo que se agregue. Lucy nunca debe decir que "registró" algo si esto se lanzó — ver `AsistenteRepository._intentarRegistrarYConfirmar`, que centraliza el manejo de este caso en los 3 lugares donde el asistente registra transacciones.

**Importante — qué significa `saldoActual` en una tarjeta de crédito:** en cuentas normales (efectivo/débito/vale/otro) `saldoActual` es dinero del usuario. En una cuenta `credito` es lo que le queda **DISPONIBLE** de su línea de crédito — no lo que debe — igual que lo muestra la app del banco. Se eligió así (y no guardar la deuda directamente) para que `Transaccion.efectoEnSaldo` sea siempre la misma fórmula simple en cualquier tipo de cuenta: un gasto resta, un ingreso suma. La deuda real nunca se guarda: se calcula sola con `Cuenta.deudaActual` (`limiteCredito - saldoActual`), y se muestra en su propia tarjeta como referencia (`CuentaTile`) — pero **nunca entra en el patrimonio total**, ver siguiente punto.

**El patrimonio total NUNCA incluye tarjetas de crédito (decisión explícita del usuario):** `Cuenta.efectoEnPatrimonio` devuelve `0` para cualquier cuenta `credito` — ni suma lo disponible (es línea del banco, no del usuario) ni resta la deuda. NeroMoney no calcula "patrimonio neto" al estilo banco/contable; el patrimonio total es solo la suma del dinero real del usuario (efectivo/débito/vale/otro). La deuda de una tarjeta se ve únicamente en su propia tarjeta (`CuentaTile`), nunca mezclada en el número principal de Inicio.

**Resincronización manual (pagos/aumentos de límite):** NeroMoney no vincula el banco real (ver "Filosofía sobre tarjetas de crédito" abajo), así que no puede detectar solo cuándo el usuario pagó su tarjeta o le subieron el límite. La pantalla de Cuentas tiene un botón "Editar" (`widgets/editar_cuenta_sheet.dart`) para que el usuario actualice `saldoActual` (disponible) y `limiteCredito` a mano cuando eso pase en la vida real.

La UI (`CuentaTile` en `features/accounts/widgets/`) usa proporción real de tarjeta física (`AspectRatio(1.586)`, degradado oscuro teñido con el color de la cuenta, brillo ambiental, insignia de ícono) — el usuario pidió que se vieran como tarjetas de verdad y dio un ejemplo de código de Stitch; se adaptó ese ejemplo a `Cuenta` (no se creó un modelo/colección paralelos) preservando las decisiones ya tomadas: "DISPONIBLE" sigue siendo el dato principal (nunca "Saldo Deudor", que es lo que traía el ejemplo original) y nunca se fabrica actividad bancaria falsa (ej. "depósito recibido") para cuentas normales.

**Personalización de cuenta (`ultimos4Digitos`, `colorPersonalizado`):** ambos 100% opcionales. `ultimos4Digitos` es solo para diferenciar visualmente una tarjeta física de una digital del mismo banco — se muestra como "•••• 4821" en `CuentaTile` y en `AccountDetailScreen`; nunca se pide ni se guarda el número completo. `colorPersonalizado` guarda el ARGB (`Color.toARGB32()`, no `.value` — está deprecado en esta versión de Flutter) elegido de `paleta_cuentas.dart`; si es null, `CuentaTile` usa el color por defecto según el tipo. Ambos se editan desde `AccountDetailScreen` → "Editar" (`EditarCuentaSheet`), no desde el alta rápida (`CuentaFormCard`), que se mantiene mínima a propósito.

**Pantalla de detalle de cuenta** (`AccountDetailScreen`, ruta `/accounts/detalle`, recibe el `cuentaId` por `extra`): sigue `15._detalle_de_tarjeta_nu_cr_dito` del Stitch pero solo con datos reales — sin CVV dinámico, "congelar tarjeta", CLABE ni límites de seguridad (no hay vinculación bancaria real, esas funciones no existen de verdad). Muestra la tarjeta visual grande, deuda/disponible/corte si es crédito, un botón para eliminar la cuenta (con confirmación), y los movimientos de ESA cuenta en particular (`transaccionesPorCuentaProvider`, un `StreamProvider.family` sobre `TransaccionesRepository.observarPorCuenta`).

## Diseño: "Obsidian Cyber-Glass"

Implementado en `lib/core/theme/`. Fondo obsidiana `#0A0D14`, superficies "glass" con blur, acentos cian eléctrico `#00F0FF` y violeta `#8A2BE2`, verde esmeralda para ingresos / rosa carmesí para gastos. Tipografía Outfit (UI) + JetBrains Mono (cifras/timestamps). Botones y chips en píldora, tarjetas con esquinas 16–24px. Ver `app_colors.dart` como fuente de verdad de la paleta y la guía completa en Stitch (ruta arriba) para cualquier detalle no cubierto ahí.

**Regla explícita del usuario:** al construir o ajustar cualquier pantalla, revisar primero la pantalla equivalente en `stitch_neromoney_ai_finance_app/` y ser fiel a ese diseño (layout, jerarquía de información, qué se muestra y cómo) — corrigiendo solo errores simples de redacción/lógica que traiga el mockup, no reinterpretando el diseño libremente. Si una pantalla de Stitch incluye elementos que dependen de una función que aún no existe (ej. notificaciones, transferencias, análisis con IA), construir primero la versión fiel al diseño con lo que sí existe, y dejar explícito qué falta para el resto.

## Alcance del MVP (v1) vs. pospuesto

**En v1:** login + onboarding simplificado (2 pasos: moneda y nombre del asistente — crear una cuenta NO es parte del onboarding, es opcional desde la pantalla de Cuentas), registro de gastos/ingresos por texto/voz vía IA con slot-filling, cuentas manuales (sin sync bancaria real), dashboard, historial con filtros, reportes básicos, registro manual como alternativa a la IA.

**Pospuesto para v2 (no construir sin confirmarlo primero):** vinculación bancaria real/Open Banking (Belvo/Finerio), OCR de tickets, score crediticio, simulador de Meses Sin Intereses (MSI). Ya hay pantallas diseñadas en Stitch para estas si se retoman.

**Filosofía sobre tarjetas de crédito (explícita del usuario):** NeroMoney no busca ser el banco — no simula fechas de corte, pagos mínimos ni intereses, porque cada banco ya lo hace en su propia app. Su función es saber en qué, dónde y con qué cuenta se gastó el dinero, todo en un solo lugar. Por eso una tarjeta de crédito solo guarda: nombre, gastos hechos con ella, y opcionalmente su límite — fecha de corte/día de pago son datos de referencia opcionales, nunca algo que la app calcule o recuerde activamente.

## Backend de IA (Cloud Functions)

**Por qué existe** (decisión explícita del usuario, no negociable): la API key de DeepSeek nunca debe vivir dentro del código de Flutter — quedaría compilada en el APK y cualquiera podría extraerla descompilando la app para usarla gratis a costa nuestra, o para saltarse la suscripción de pago por completo. La solución es un intermediario: la app le habla a una Cloud Function (autenticada con la sesión de Firebase Auth de quien la llama), y solo esa función, corriendo en el servidor de Google, conoce la key y habla con DeepSeek.

- Código en `neromoney_app/functions/` (Node.js 20, `firebase-functions` v2, SDK oficial `openai` apuntando a `baseURL: https://api.deepseek.com` — DeepSeek es compatible con la API de OpenAI).
- Función `interpretarMensajeIA` (`onCall`, en `functions/index.js`): recibe `{ mensaje }`, exige `request.auth` (si no hay sesión, `HttpsError('unauthenticated', ...)`), le pide a `deepseek-v4-flash` que llame a la tool `registrar_transaccion` (monto, tipo, categoría, descripción, `cuentaMencionada` tal cual la dijo el usuario) y regresa `{ tipo: 'transaccion_extraida', datos }` o, si el modelo no encontró suficiente información, `{ tipo: 'mensaje', texto }`.
- **La resolución de a qué CUENTA aplica la IA la hace la app, no el modelo** — el modelo solo entrega `cuentaMencionada` (el texto literal que usó el usuario); el algoritmo de 4 niveles de "Resolución de ambigüedad de cuenta" (ver abajo) corre en Dart, con las cuentas reales del usuario desde Firestore. Así el comportamiento es determinista y no depende de qué tan bien "razone" la IA sobre cuentas que ni conoce.
- La API key vive únicamente en Google Secret Manager, nunca en un archivo del repo: se guarda con `firebase functions:secrets:set DEEPSEEK_API_KEY` (pide el valor por prompt) y se lee en el código con `defineSecret('DEEPSEEK_API_KEY').value()` — ese método falla a propósito si se llama durante el despliegue, solo funciona en tiempo de ejecución.
- **Requiere el plan Blaze de Firebase** (pago por uso) — Cloud Functions no se puede desplegar en el plan gratuito Spark, así sea una función trivial. Blaze incluye una capa gratuita mensual amplia; para el uso de una sola persona el costo real es prácticamente $0, pero sí exige vincular una tarjeta (lo hace el usuario en la consola de Firebase, nunca Claude).
- Modelos vigentes de DeepSeek al momento de escribir esto: `deepseek-v4-flash` (rápido/barato, el que usamos) y `deepseek-v4-pro` (más capaz, para si algún día se necesita más razonamiento). Los nombres viejos `deepseek-chat`/`deepseek-reasoner` ya están descontinuados — **siempre confirmar el modelo vigente en la documentación oficial antes de tocar este archivo**, DeepSeek los ha ido renombrando.
- La app manda `{ mensaje, historial, transaccionesRecientes }` en cada llamada. **`transaccionesRecientes`** (últimos ~20 movimientos reales: monto/tipo/categoría/descripción/fecha/cuenta, ver `AsistenteRepository._transaccionesRecientes`) es la fuente de verdad para resolver referencias a gastos pasados (ej. un reembolso) y para responder preguntas simples de gasto ("¿cuánto llevo gastado hoy?") — deliberadamente NO se usa el texto del chat para esto, porque el chat se puede limpiar (`AsistenteRepository.limpiarHistorial`, botón en `AssistantChatScreen`) sin que eso le haga perder la memoria financiera real. `historial` (ahora solo ~6 mensajes) quedó reducido a solo dar continuidad conversacional inmediata, no memoria de hechos.
- **Saludo fijo (no generado por la IA):** `AsistenteRepository.saludarSiEsNuevo` guarda un texto fijo de la app la primera vez que se abre el chat vacío (o tras "Limpiar conversación") — deliberadamente NO se le pide al modelo que se presente, porque en pruebas reales a veces se ponía "creativo" (inventó una historia sobre su "superpoder limitado"). El prompt también se ajustó para que ante saludos/plática casual conteste en una sola oración neutra, sin inventar narrativas ni devolver preguntas de cómo está.
- **Corrección de nombres de cuenta mal transcritos por voz:** `speech_to_text` no soporta darle pistas de vocabulario (revisado en el código del paquete, no existe esa opción) — así que un nombre propio como "Rappi Card" a veces se transcribe mal. La app manda `nombresCuentas` (los nombres reales, tal cual, de `cuentasProvider`) como contexto, y el prompt le pide al modelo que si `cuentaMencionada` se parece —aunque sea fonéticamente— a alguno, devuelva el nombre EXACTO de la lista. Como respaldo adicional, `AsistenteRepository._resolverYRegistrar` usa `contains` bidireccional en vez de igualdad exacta al emparejar el nombre (mismo criterio que ya usaba `_resolverRespuestaDeCuenta` para contestar "¿con qué cuenta fue?").
- **Segunda herramienta: `consultar_gasto_periodo`** (`periodo`: dia/semana/mes; `diasAtras`: entero, solo aplica si `periodo` es `dia` — 0=hoy, 1=ayer, 2=anteayer, 3=hace tres días, etc). Para preguntas de total de gasto, Lucy NO suma nada ella misma con `transaccionesRecientes` (esa lista es limitada a ~20 y sumar a mano gastos e ingresos mezclados es justo el tipo de error que ya se vio — contaba reembolsos como gasto) NI calcula la fecha ella misma — solo identifica de qué día/periodo habla el usuario. En vez de eso llama a esta función, y la app responde con el número exacto: consulta TODOS los movimientos del periodo directo de Firestore y los calcula con `ResumenGastos.calcular` (`lib/features/transactions/data/resumen_gastos.dart`) — el mismo helper que usa "Gastos del mes" en Inicio, para que nunca haya dos cálculos que puedan desincronizarse. A diferencia de semana/mes (que siempre van desde su inicio HASTA hoy), un `dia` puntual es una ventana cerrada de un solo día (`AsistenteRepository._responderConsultaGasto`).
- **Cancelar/borrar por chat: decisión explícita de NO darle ese permiso a Lucy todavía.** Borrar es una acción destructiva sobre datos reales, y ya se vio que el modelo puede equivocarse (confirmaciones falsas). El prompt le instruye que ante "cancela"/"borra"/"elimina" un movimiento ya registrado, explique que vaya a Movimientos y deslice para borrar ahí (con confirmación) — nunca que invente una función que no tiene. Si en el futuro se quiere permitir desde el chat, debe ir con una confirmación explícita "Sí/No" antes de ejecutar, igual que ya tiene el borrado manual.
- **Riesgo real detectado en pruebas: confirmaciones falsas.** A veces el modelo respondía en texto libre ("Ingreso de $300 registrado...") con el mismo tono que una confirmación real, SIN llamar a la función — nada se guardaba, pero el usuario no tenía forma de saberlo. Se reforzó el prompt para prohibir explícitamente ese patrón, y como defensa adicional cada `MensajeChat` tiene un campo `registrado` (true solo si vino justo después de una llamada real a `TransaccionesRepository.registrarTransaccion`) que se muestra como una marca "✅ Registrado" en el chat (`BurbujaMensaje`) — si algún día una confirmación aparece SIN esa marca, es señal de que esto volvió a pasar.
- El campo `categoria` de la tool usa `enum` (no solo una descripción en texto) con la lista exacta de `categoria.dart` — probado en vivo: sin el `enum`, DeepSeek a veces inventaba una categoría parecida (ej. "café") que no coincidía con ninguna de la app. Si se agrega una categoría nueva en Dart, hay que agregarla también en `CATEGORIAS_GASTO`/`CATEGORIAS_INGRESO` de `functions/index.js`.

**Estado:** desplegado y probado en el proyecto `neromoneyapp` (plan Blaze activo desde sept. 2026). La key ya está en Secret Manager.

Desplegar cambios en las funciones: `cd neromoney_app/functions && npm install`, luego `firebase deploy --only functions` desde `neromoney_app/`. Para cambiar la API key: `firebase functions:secrets:set DEEPSEEK_API_KEY --data-file=<archivo>` (nunca pegarla directo en la terminal como texto persistente — usar un archivo temporal y borrarlo después).

## Flujo de IA — slot-filling (al implementar `/assistant`)

Cuando Lucy extrae una transacción de un mensaje pero falta un dato obligatorio (típicamente la cuenta de pago):

1. Crear un doc `borrador_pendiente` en Firestore con los campos ya extraídos, el campo faltante y la pregunta hecha. Expira a la ~1 hora si no se resuelve (deja de bloquear el chat).
2. En el siguiente mensaje del usuario, si hay un borrador pendiente, se manda junto con el mensaje a la IA vía function calling para decidir: completar la transacción / es una transacción nueva no relacionada / seguir la conversación.
3. Los borradores pendientes también se muestran como tarjetas en la UI (no solo en el chat), completables con un tap, sincronizadas entre dispositivos.

**Resolución de ambigüedad de cuenta** (priorizando velocidad sobre precisión perfecta, nunca preguntar en texto libre si se puede evitar):
1. Coincidencia exacta del nombre → usar esa.
2. Término genérico + una sola cuenta de ese tipo → usar esa.
3. Término genérico + varias cuentas → usar la predeterminada/más reciente, guardar, avisar con opción de "Cambiar" en un tap.
4. Sin ninguna pista → chips de selección rápida (nunca pregunta abierta).

## Monetización

El asistente de IA es lo único de pago (registro manual, cuentas y reportes son gratis). Precios: **$2.19 USD/mes** o **$19.99 USD/año**. Debe cobrarse vía Google Play Billing / Apple In-App Purchase (requisito de tienda para contenido digital dentro de la app, no vía procesador externo como Polar.sh). Pendiente integrar `in_app_purchase` o RevenueCat para gatear el acceso al asistente detrás de la suscripción.

## Comandos útiles

```
cd neromoney_app
flutter pub get
flutter analyze
flutter test
flutter run
```

Reglas de Firestore: editar `neromoney_app/firestore.rules` y desplegar con `firebase deploy --only firestore:rules` (requiere `firebase login` y el proyecto `neromoneyapp` seleccionado).

**Índices de Firestore** (`firestore.indexes.json`, referenciado desde `firebase.json`): cualquier query que combine un `.where(campo, isEqualTo: ...)` con un `.orderBy(otroCampo)` en un campo DISTINTO necesita un índice compuesto — si no existe, Firestore no falla en tiempo de compilación, falla en tiempo de ejecución con `[cloud_firestore/failed-precondition] FAILED_PRECONDITION: The query requires an index` (pasó con `TransaccionesRepository.observarPorCuenta`, que filtra por `cuentaId` y ordena por `fecha`). En vez de crear el índice a mano desde el enlace que da el error, se define aquí y se despliega con `firebase deploy --only firestore:indexes` — así queda versionado en el repo y no depende de que alguien le dé clic manual en la consola. Tarda uno o dos minutos en terminar de construirse después de desplegar. Si se agrega una query nueva con este patrón (filtro + orden en campos distintos), hay que agregar su índice aquí ANTES de que falle en el dispositivo.
