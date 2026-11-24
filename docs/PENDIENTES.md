# Pendientes y contexto para la siguiente sesión

Última actualización: 23 de noviembre de 2026. Todo lo de abajo ya está
en `main` y publicado en https://neromoneyapp.web.app (app web, Cloud
Functions y reglas de Firestore).

## 1. Arreglar el diseño de Libreta y Compartido en escritorio (PRIORIDAD)

Lo pidió el usuario: en la web de escritorio, **Libreta** (`/libreta`) y
**Compartido** (`/compartido`) no siguen el diseño del resto de la app.

- Se ven como una columna angosta centrada (`ConstrainedBox(maxWidth: 900)`)
  con **líneas negras verticales a los lados** sobre el fondo ilustrado.
- No tienen el encabezado ni la composición de las demás secciones de
  escritorio, y la flecha de "Atrás" sobra en escritorio (ya hay menú lateral).

Archivos:
- `lib/features/libreta/libreta_screen.dart`
- `lib/features/compartido/compartido_screen.dart`

Cómo lo hacen las otras secciones (seguir ese patrón):
- `lib/features/reports/reports_screen.dart` decide con
  `esEscritorio(context)` y en escritorio muestra
  `lib/features/reports/widgets/reportes_escritorio.dart`.
- Mismo patrón en `movements_screen.dart`, `accounts_screen.dart`,
  `home_screen.dart` y `profile_screen.dart`: una vista para teléfono y otra
  para escritorio (`*_escritorio.dart`), con las piezas de
  `lib/core/widgets/piezas_escritorio.dart` (`TarjetaEscritorio`,
  `BotonContorno`, encabezados) y, en teléfono, `piezas_movil.dart`.
- Con fondo ilustrado (planes Plus/Pro) el `Scaffold` debe ser transparente
  (ver cómo `MarcoEscritorio` / `FondoTema` lo manejan) para no tapar el fondo
  con un panel oscuro.

Idea de diseño para escritorio:
- **Libreta**: resumen ("Te deben" / "Debes") arriba en tarjetas grandes y la
  lista en dos columnas, o lista a la izquierda y detalle del préstamo a la
  derecha, como Cuentas.
- **Compartido**: tarjeta del grupo a la izquierda (miembros, código) y las
  pestañas Gastos / Cuentas claras / Metas a la derecha.

Hay pruebas de pantalla en `test/pantallas_nuevas_test.dart` (teléfono 400 px
y escritorio 1400 px). Para ver capturas:
`flutter test test/pantallas_nuevas_test.dart --dart-define=CAPTURAS=<carpeta>`.

## 2. Lo que se hizo en esta sesión (para contexto)

- **Lucy**: registra gastos de días pasados (`fecha` y `hora` en la
  herramienta `registrar_transaccion`; la app usa
  `AsistenteRepository.resolverFecha`). Sin hora → mediodía de ese día y
  `sinHora: true`. Nunca fechas futuras ni de hace más de un año.
- **Lucy**: presupuestos y metas (`gestionar_presupuesto`, `gestionar_meta`,
  `consultar_planeacion` en `functions/index.js`; la lógica vive en
  `asistente_repository.dart`). Respeta el límite del plan Gratis.
- **Libreta** (`lib/features/libreta/`): préstamos dados y recibidos, pagos en
  partes, cuenta de origen, fecha de pago, llamar/WhatsApp. Sus movimientos
  llevan `libretaId` y no cuentan como gasto (`Transaccion.esMovimientoInterno`).
- **Compartido (Pro)** (`lib/features/compartido/`, `functions/compartido.js`):
  grupos con código de 6 caracteres, gastos divididos, "cuentas claras" y metas
  en común. Crear requiere Pro; unirse es gratis. Reglas en `firestore.rules`.
- **Perfil**: foto, frase y cumpleaños (`editar_perfil_screen.dart`).
- **Recordatorios web**: push con FCM (`web/firebase-messaging-sw.js`) y la
  función programada `recordatoriosWeb` (cada 15 min, por zona horaria).
- **Pagos cerrados**: `suscripcionesAbiertas = false` en
  `lib/features/planes/data/membresia.dart`. Al tocar un plan sale "Las
  suscripciones aún están pendientes…". Cambiar a `true` cuando Polar pase a
  producción.
- **Micrófono del chat**: usaba `GestureDetector` dentro de un `Tooltip` y se
  cortaba en teléfono; ahora usa `Listener`.

## 3. Otros pendientes

- Polar a producción: organización verificada, Términos y Privacidad,
  productos, token y webhook de producción; luego `POLAR_SERVIDOR=production`
  y los ids en `functions/.env`, desplegar funciones y poner
  `suscripcionesAbiertas = true`.
- Con los pagos cerrados nadie puede crear grupos de Compartido (requiere Pro).
- Si se borra un préstamo de la Libreta, sus movimientos quedan en Movimientos
  (decisión a propósito, para no mover saldos sin confirmación).
- Probar en un teléfono real: dictado en el chat, recordatorios push, Libreta
  y Compartido.

## Cómo publicar

- Web: `bash tool/desplegar_web.sh`
- Funciones y reglas: `firebase deploy --only functions,firestore:rules`
- Pruebas: `flutter test` (136) y `cd functions && npm test` (39).
- El repositorio es público: revisar que no se suba ningún secreto. Las llaves
  viven en Secret Manager; `functions/.env` y `CLAUDE.md` están en `.gitignore`.
