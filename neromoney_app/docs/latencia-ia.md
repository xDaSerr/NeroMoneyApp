# Latencia del asistente — 8 de septiembre de 2026

## Cambios

- La función usa `deepseek-v4-flash` con `thinking: {type: "disabled"}`. Se mantienen las cinco herramientas, el prompt y todo el contexto. El SDK de JavaScript envía el campo directamente en el cuerpo de la petición; `extra_body` corresponde al ejemplo de Python de la [documentación oficial](https://api-docs.deepseek.com/guides/thinking_mode/).
- La app lee historial, movimientos recientes y borrador en paralelo. Espera las tres lecturas antes de guardar el mensaje nuevo, para no duplicarlo en el contexto.
- Se conserva el registro en Firestore y su validación de saldo antes de mostrar la confirmación. No se agregaron atajos que registren dinero sin pasar por el flujo existente.

## Medición real del modelo

Evaluación desde esta computadora hacia DeepSeek, con ejemplos ficticios y sin escrituras en Firestore. Mismo handler y mismo contexto antes/después; tres repeticiones por modo, alternando el orden. No mide dictado, Cloud Functions ni Firestore. Es una muestra pequeña sujeta a red, caché y carga del proveedor.

Ejemplo: «Gasté 100 pesos en un café en efectivo».

| Modo | Tiempos (ms) | Promedio | Mediana |
| --- | --- | --- | --- |
| Razonamiento predeterminado | 1395, 1543, 2025 | 1654 ms | 1543 ms |
| Razonamiento desactivado | 1259, 1395, 1241 | 1298 ms | 1259 ms |

Reducción observada del promedio: **21.5 %** (356 ms). Los tokens de razonamiento pasaron de 35–55 a cero. No es una garantía del tiempo total en un teléfono.

Pasaron las 16 llamadas de evaluación: seis del café y diez casos adicionales (decimales, ingreso, consulta de gasto, consulta de saldo, compra con crédito, abono, corrección de saldo, reembolso, monto faltante y negación). La evaluación verifica tipo de operación y campos críticos; no constituye una garantía sobre todas las frases posibles.

## Verificación y reproducción

- `flutter test`: 52 pruebas correctas, incluidas tres nuevas que verifican historial previo, confirmación posterior al registro, fallo de IA sin movimientos y saldo insuficiente.
- `flutter analyze`: sin errores ni advertencias; permanece el aviso informativo previo en `editar_cuenta_sheet.dart:90`.
- Desde `functions/`, `npm test`: ocho pruebas del contrato, contexto, herramientas, autenticación y privacidad de métricas.
- Evaluación opcional con coste de API: desde la app, `node functions/scripts/comparar_latencia.cjs --ejecutar`. Requiere la sesión existente de Firebase CLI en Windows y lee el secreto solo en memoria. El informe queda en `build/latencia-deepseek.json`; nunca se guarda la clave ni el razonamiento del modelo. El script solo interpreta ejemplos; no registra operaciones.

## Diagnóstico por etapas

`AsistenteRepository.ultimaMedicion` y el evento local `NeroMoney.LatenciaAsistente` contienen `preparacion_ms`, las tres lecturas, `guardar_mensaje_ms`, `funcion_ia_ms`, `resolver_y_guardar_ms`, `total_ms` y `fallo`, según las etapas ejecutadas. Los tiempos de lectura se superponen: no deben sumarse. La llamada a la función incluye transporte y posibles arranques en frío; no equivale al tiempo exclusivo del modelo.

Cloud Logging recibe `latencia_deepseek`: duración, modelo, modo, resultado y conteos de tokens. Las métricas no incluyen mensajes, importes, nombres de cuentas ni claves. Para revertir solo el cambio de razonamiento, retirar `thinking` de la petición y desplegar únicamente `functions:interpretarMensajeIA`. No se modificaron las instancias mínimas ni los límites de contexto.

## Entrega verificada

Función `interpretarMensajeIA` desplegada y `ACTIVE` el 2026-09-08 a las 19:28:51 UTC. Se descargó su fuente y se comprobó que el hash de `index.js` coincide con el archivo probado. El respaldo de la versión anterior está en `build/ia-source-before.zip` (local, excluido del repositorio).

APK release de 62 476 183 bytes instalado con `adb install -r` en el Samsung SM-S938U1 conectado. Inicio de `MainActivity` correcto y proceso activo; se conservaron los datos. No se dictaron gastos de prueba en la cuenta del usuario. La mejora completa de tiempo en el teléfono queda pendiente de mediciones de uso real por etapas.
