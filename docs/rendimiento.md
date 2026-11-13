# Rendimiento — 7 de septiembre de 2026

Se conserva la píldora, la elevación central de 280 ms, los colores, las sombras y las tipografías del diseño.

## Cambios

- El volumen del micrófono tiene un `ValueListenable` independiente. Actualiza el `CustomPainter` del halo sin notificar a todo el shell ni al chat. Las muestras iguales no generan notificaciones; los callbacks antiguos se siguen descartando al cancelar. Las transcripciones repetidas tampoco reconstruyen la interfaz.
- Los destinos y el avatar de navegación se reutilizan durante la animación. La pintura del fondo y la del avatar están aisladas; los colores del fondo se comparan por contenido.
- Cuentas utiliza una lista que construye las tarjetas al acercarse al área visible. Conserva filtros, separación, orden, acceso al detalle y botón de alta.
- El chat solo sigue un mensaje nuevo si ya se estaba cerca del final. Dictar mientras se lee el historial conserva la posición. Enviar desde el chat mantiene su desplazamiento explícito al final.
- Los avatares comparten una única entrada de caché para la foto personalizada, en lugar de crear una imagen decodificada por burbuja. Cambiar de foto reemplaza esa entrada.
- Los streams por cuenta y por rango se liberan al perder su último consumidor. Cambiar periodos de Reportes ya no acumula consultas activas.
- Se incluyen Outfit Regular/SemiBold/Bold y JetBrains Mono Medium: exactamente los archivos de `google_fonts 8.2.1`, verificados por SHA-256. Sus 256 748 bytes evitan descargar tipografías en el primer uso. Licencias OFL incluidas y registradas en la app.

## Comparación reproducible local

La misma prueba de widgets, con 30 cuentas ficticias, 80 mensajes y 120 muestras de volumen, antes y después de modificar el código:

| Medida | Antes | Después |
|---|---:|---:|
| Tarjetas montadas al abrir Cuentas (viewport de prueba local) | 30 | 1 |
| Notificaciones generales por 120 muestras de volumen | 120 | 0 |
| Desplazamiento involuntario al dictar leyendo el historial | 3797,89 px | 0 px |

El número de tarjetas montadas depende del tamaño de pantalla; se mantienen las visibles y las cercanas. Estos números miden trabajo y comportamiento, **no FPS ni un porcentaje de mejora de velocidad**.

## Verificación

49 pruebas locales pasan, incluidas navegación por gesto, reintentos tras silencio, revisión del dictado, voz, transferencias, liberación de suscripciones, caché compartida y conservación del scroll.

La prueba de integración completa también pasó en Android 36 (emulador Pixel 7, 1080 × 2400): 3 tarjetas montadas de 30 al abrir, 0 notificaciones generales por 120 muestras de volumen y 0 px de desplazamiento involuntario. Se comprobó visualmente la pantalla de Cuentas. La conexión ADB se aisló en el puerto 5038 para que Flutter no esperase al consultar otro dispositivo conectado.

APK release generado en `build/app/outputs/flutter-apk/app-release.apk` (62 394 071 bytes), instalado y abierto correctamente en el emulador. Conserva la firma de desarrollo que ya configura el proyecto; no se modificó la firma ni se publicó en una tienda.

```powershell
flutter test --no-pub
$env:ANDROID_ADB_SERVER_PORT='5038' # Solo si se usa el servidor aislado de esta sesión.
flutter test integration_test/rendimiento_test.dart -d emulator-5554 --no-pub --reporter expanded
flutter analyze --no-pub
flutter build apk --release
```

El escenario Android usa proveedores en memoria y un motor de dictado simulado: no inicia sesión, no escucha audio, no invoca la IA y no registra movimientos reales. El emulador de prueba es `NeroMoney_API36`; se conserva el AVD Pixel existente.

Después de ejecutar las pruebas de integración, compilar release con el comando completo (sin `--no-pub`): esta versión del SDK necesita regenerar el registro nativo para excluir `integration_test` de release.

Para medir tiempos de frames y consumo reales falta una ejecución en modo profile en un teléfono físico. El usuario solicitó probar únicamente en emulador. Las pruebas de debug/emulador no permiten prometer la misma fluidez ni extrapolar FPS al dispositivo. Véase la [guía oficial de medición de Flutter](https://docs.flutter.dev/perf/ui-performance).

El analizador tiene una observación de estilo previa en `editar_cuenta_sheet.dart:90` (llaves en un `if`), ajena a estos cambios.
