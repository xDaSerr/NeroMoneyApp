# NeroMoney

App de finanzas personales para Android/iOS con un asistente de IA conversacional (nombre configurable, por defecto "Lucy") al que le puedes decir cosas como *"gasté 200 en un café"* y lo registra solo.

Este documento es el mapa del proyecto: para qué sirve cada carpeta, cómo está guardada la información, y qué falta por construir. Se actualiza cada vez que se agrega algo importante — si vuelves después de un tiempo, empieza por aquí.

## Stack

- **Flutter** (Dart) — Material 3, sin soporte de modo claro (el diseño es oscuro por decisión de marca, no accesibilidad).
- **Firebase**: Authentication (email/contraseña + Google), Cloud Firestore (base de datos y sincronización).
- **Riverpod** (`flutter_riverpod`) — manejo de estado.
- **go_router** — navegación, con `StatefulShellRoute` para las 5 pestañas y redirecciones automáticas según sesión/onboarding.
- **DeepSeek API** — pendiente de integrar, para el asistente de IA (function calling / JSON mode).
- Diseño visual: sistema **"Obsidian Cyber-Glass"** (ver `stitch_neromoney_ai_finance_app/obsidian_cyber_glass/DESIGN.md` en la raíz del repo, generado con Google Stitch).

## Estructura de carpetas

```
lib/
  core/
    theme/            → app_colors.dart, app_text_styles.dart, app_theme.dart
                         (tokens exactos del sistema de diseño Obsidian Cyber-Glass)
    widgets/           → GradientButton (botón con micro-animación al presionar),
                         GlassCard (vidrio esmerilado), PlaceholderScreen
    router/            → app_router.dart (todas las rutas + lógica de redirección),
                         app_shell.dart (barra de navegación de 5 pestañas),
                         go_router_refresh_stream.dart (conecta el stream de auth con go_router)

  features/
    auth/              → login, registro, recuperar contraseña, AuthRepository (Firebase Auth + Google)
    onboarding/        → flujo de 2 pasos (moneda + nombre del asistente), PerfilUsuario/PerfilRepository
    accounts/          → modelo Cuenta, CuentasRepository, pantalla de gestión de cuentas
    transactions/      → modelo Transaccion, TransaccionesRepository, Movimientos, alta manual
    home/              → Dashboard (Inicio)
    profile/           → Perfil (por ahora solo cierre de sesión)

  main.dart            → inicializa Firebase y arranca la app
  firebase_options.dart → generado por FlutterFire CLI, no editar a mano
```

**Patrón dentro de cada feature:** `data/` (modelos + repositorio que habla con Firestore), `providers/` (los Provider de Riverpod que exponen ese repositorio y sus streams a la UI), y los archivos de pantalla sueltos en la raíz del feature. Si agregas una función nueva, sigue este mismo patrón.

## Modelo de datos (Firestore)

Todo vive bajo el usuario autenticado — nunca hay una colección "global" de datos de usuarios distintos mezclados:

```
usuarios/{uid}                         → PerfilUsuario: moneda, nombreAsistente, onboardingCompletado
usuarios/{uid}/cuentas/{id}            → Cuenta: nombre, tipo, saldoActual, (opcional si es crédito: límite/fechas)
usuarios/{uid}/transacciones/{id}      → Transaccion: monto, tipo (gasto/ingreso), categoría, cuentaId, fecha
```

**Reglas de seguridad** (`firestore.rules`): cada usuario solo puede leer/escribir su propio subárbol `usuarios/{uid}/...`; todo lo demás está bloqueado por defecto.

**Detalle importante:** registrar una transacción actualiza el `saldoActual` de su cuenta de forma atómica (`TransaccionesRepository.registrarTransaccion` usa `runTransaction` de Firestore) — nunca se escribe la transacción sin ajustar el saldo, o viceversa.

## Cómo correr el proyecto

Entorno ya configurado en esta máquina: Flutter en `C:\src\flutter`, Android SDK en `%LOCALAPPDATA%\Android\sdk`, JDK del propio Android Studio (`C:\Program Files\Android\Android Studio\jbr`). Si es una máquina nueva, hay que instalar esos tres antes de nada.

```powershell
$env:Path += ";C:\src\flutter\bin;$env:LOCALAPPDATA\Android\sdk\platform-tools"
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\sdk"
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"

flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell am start -n com.neromoney.neromoney_app/.MainActivity
```

Proyecto de Firebase: `neromoneyapp` (consola: https://console.firebase.google.com/project/neromoneyapp).

## Qué está hecho (funcional, probado en dispositivo real)

- Login con email/contraseña y con Google (Firebase Auth).
- Onboarding: elegir moneda + nombrar al asistente (2 pasos, sin fricción).
- Cuentas: crear/eliminar cuentas (efectivo, débito, crédito, vale, otro), opcionalmente con límite de crédito.
- Movimientos: historial en tiempo real + alta manual de gastos/ingresos (monto, categoría, cuenta, fecha, descripción).
- Dashboard: patrimonio total y lista de cuentas; aviso si no tienes ninguna cuenta todavía.
- Ícono de la app y tema visual completo aplicados.

## Qué falta (roadmap)

1. **Asistente de IA (DeepSeek)** — la función estrella. Incluye el flujo de "slot-filling" para preguntar el método de pago cuando falta, con borradores pendientes en Firestore para no bloquear el chat si el usuario no responde.
2. **Reportes** — gráficas de gastos por categoría, comparativas mensuales.
3. **Voz** (`speech_to_text` / `flutter_tts`) — ya está en `pubspec.yaml`, falta conectarlo a la UI del chat.
4. **Suscripción** ($2.19/mes, $19.99/año) vía **Google Play Billing** (no Polar.sh — ver razón abajo) para desbloquear el asistente de IA.
5. Perfil completo: editar cuentas existentes, configurar nombre/cuenta predeterminada del asistente, cambiar moneda.

**Pospuesto para v2** (fuera del alcance actual, no construir todavía): vinculación bancaria real, escaneo de tickets por OCR, score crediticio, simulador de Meses Sin Intereses.

## Decisiones importantes a recordar

- **Nunca** usar Polar.sh (u otro procesador externo) para cobrar la suscripción dentro de la app — Google Play/Apple exigen su propio sistema de facturación para desbloquear contenido digital dentro de la app. Ambas tiendas bajan su comisión de 30% a 15% para el primer $1M USD anual por desarrollador (automático).
- El onboarding **no** debe pedir crear una cuenta — es opcional a propósito, para reducir fricción. El Dashboard avisa si falta, no lo bloquea.
- `go_router`'s `redirect` no reacciona solo a cambios en Firestore (solo a cambios de sesión de Firebase Auth o navegaciones explícitas) — cualquier pantalla que cambie algo que afecte una redirección (ej. completar el onboarding) debe navegar explícitamente después, no asumir que el redirect lo hará solo.
- Los providers de Riverpod que dependen del uid del usuario usan `currentUidProvider` (en `auth_providers.dart`), no `authStateChangesProvider` directo — este último puede devolver `null` por una fracción de segundo al recién crearse (antes de su primer evento del stream) aunque Firebase ya tenga la sesión lista.
