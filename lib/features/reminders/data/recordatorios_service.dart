import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notificaciones locales (`flutter_local_notifications`) que recuerdan
/// registrar gastos — pedido explícito del usuario: "Lucy: Hola, te
/// recuerdo ingresar tus gastos..." a mediodía y "¿Registraste tus gastos
/// hoy?" en la noche. 100% en el dispositivo, sin backend ni Cloud
/// Function: no dependen de que el usuario tenga la app abierta ni de
/// datos que cambien en el servidor, así que no hay razón para pagar por
/// infraestructura de push remoto para esto.
///
/// `AndroidScheduleMode.inexactAllowWhileIdle` a propósito (no `exact*`):
/// un recordatorio de "registra tus gastos" no necesita caer al minuto
/// exacto, y así se evita pedir el permiso especial `SCHEDULE_EXACT_ALARM`
/// (Android 12+), que Google audita más y que este tipo de aviso no
/// justifica.
class RecordatoriosService {
  RecordatoriosService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _listo = false;

  static const _idMediodia = 1001;
  static const _idNoche = 1002;
  static const _canalId = 'recordatorios_gastos';
  static const _canalNombre = 'Recordatorios de gastos';
  static const _canalDescripcion =
      'Avisos para no olvidar registrar tus movimientos del día.';

  /// Prepara el plugin y detecta la zona horaria real del dispositivo
  /// (`flutter_timezone` — el paquete `timezone` no la detecta solo). Debe
  /// llamarse antes de programar, reprogramar o cancelar cualquier aviso;
  /// es segura de llamar varias veces (solo hace el trabajo una vez).
  /// En web, `flutter_local_notifications` no tiene implementación: ahí el
  /// aviso es un push (Firebase Cloud Messaging) que manda la Cloud
  /// Function `recordatoriosWeb` a la hora elegida, así llega aunque la app
  /// esté cerrada. La app solo registra este navegador y su zona horaria;
  /// las horas y el interruptor ya viven en el perfil.
  static bool get disponible => true;

  /// Guarda el token de este navegador y su zona horaria en el perfil
  /// (`usuarios/{uid}`). arrayUnion: varios navegadores o teléfonos del
  /// mismo usuario reciben el aviso, y repetirlo no duplica nada.
  static Future<bool> _registrarNavegador() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return false;
      String zona;
      try {
        zona = (await FlutterTimezone.getLocalTimezone()).identifier;
      } catch (_) {
        zona = 'America/Mexico_City';
      }
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'tokensWeb': FieldValue.arrayUnion([token]),
        'zonaHoraria': zona,
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      // Navegador sin push (Safari fuera de la app instalada, modo
      // incógnito) o permiso negado: simplemente no hay avisos.
      return false;
    }
  }

  static Future<void> _inicializar() async {
    if (_listo) return;
    tz_data.initializeTimeZones();
    final zona = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zona.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _listo = true;
  }

  /// Pide el permiso de notificaciones (solo hace falta en Android 13+; en
  /// versiones anteriores no existe este permiso y siempre regresa true).
  /// Se llama justo cuando el usuario activa el interruptor de
  /// recordatorios — nunca antes, para no pedir permisos sin que el
  /// usuario haya mostrado intención real de usarlos.
  static Future<bool> pedirPermiso() async {
    if (kIsWeb) {
      try {
        final ajustes = await FirebaseMessaging.instance.requestPermission();
        if (ajustes.authorizationStatus != AuthorizationStatus.authorized) {
          return false;
        }
      } catch (_) {
        return false;
      }
      return _registrarNavegador();
    }
    await _inicializar();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final concedido = await android?.requestNotificationsPermission();
    return concedido ?? true;
  }

  /// Programa (o reemplaza, si ya existían) los dos recordatorios diarios.
  /// `matchDateTimeComponents: DateTimeComponents.time` es lo que los hace
  /// diarios: el plugin calcula solo la próxima vez que da esa hora del
  /// día, sin que este código tenga que saber si ya pasó hoy o hay que
  /// esperar a mañana, y se reprograma solo cada vez que suena.
  static Future<void> programar({
    required int horaMediodiaMinutos,
    required int horaNocheMinutos,
    required String nombreAsistente,
    // Ya resuelto (ver `datosDeSaludo`, features/profile/data/saludo_usuario.dart):
    // el apodo si el usuario lo puso, si no el nombre de Google, si no el
    // correo — nunca el `PerfilUsuario.apodo` crudo, para no perder ese
    // respaldo y mandar "Hola. ¿Registraste..." sin nombre de por medio.
    required String nombreSaludo,
  }) async {
    if (kIsWeb) {
      // Solo si ya dio permiso: nunca abrir la ventana del navegador al
      // arrancar la app. Renueva el token por si el navegador lo cambió.
      try {
        final ajustes = await FirebaseMessaging.instance
            .getNotificationSettings();
        if (ajustes.authorizationStatus == AuthorizationStatus.authorized) {
          await _registrarNavegador();
        }
      } catch (_) {}
      return;
    }
    await _inicializar();

    final tituloMediodia = '$nombreAsistente 👋';
    final cuerpoMediodia =
        'Te recuerdo registrar tus gastos para llevar tus finanzas bajo '
        'control.';
    await _plugin.zonedSchedule(
      id: _idMediodia,
      title: tituloMediodia,
      body: cuerpoMediodia,
      scheduledDate: _hoyA(horaMediodiaMinutos),
      notificationDetails: _detalles(tituloMediodia, cuerpoMediodia),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    final tituloNoche = '$nombreAsistente 👋';
    final cuerpoNoche =
        'Hola, ${nombreSaludo.trim()}. ¿Registraste tus gastos hoy? Si '
        'no, ¿quieres hacerlo? No te toma más de 10 minutos.';
    await _plugin.zonedSchedule(
      id: _idNoche,
      title: tituloNoche,
      body: cuerpoNoche,
      scheduledDate: _hoyA(horaNocheMinutos),
      notificationDetails: _detalles(tituloNoche, cuerpoNoche),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// `BigTextStyleInformation` es indispensable aquí: sin ella, Android
  /// recorta el cuerpo a un renglón y medio SIEMPRE, incluso al desplegar
  /// la notificación con la flechita — el texto completo solo aparece si
  /// se declara explícitamente este estilo "de texto largo".
  static NotificationDetails _detalles(String titulo, String cuerpo) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _canalId,
        _canalNombre,
        channelDescription: _canalDescripcion,
        styleInformation: BigTextStyleInformation(cuerpo, contentTitle: titulo),
      ),
    );
  }

  /// Apaga los dos recordatorios — se llama al desactivar el interruptor.
  static Future<void> cancelarTodos() async {
    // En web basta con el interruptor apagado del perfil: el servidor no
    // le manda avisos a quien los tiene desactivados.
    if (kIsWeb) return;
    await _inicializar();
    await _plugin.cancel(id: _idMediodia);
    await _plugin.cancel(id: _idNoche);
  }

  static tz.TZDateTime _hoyA(int minutosDesdeMedianoche) {
    final ahora = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(
      tz.local,
      ahora.year,
      ahora.month,
      ahora.day,
      minutosDesdeMedianoche ~/ 60,
      minutosDesdeMedianoche % 60,
    );
  }
}
