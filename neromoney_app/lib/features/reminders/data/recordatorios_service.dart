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
        styleInformation: BigTextStyleInformation(
          cuerpo,
          contentTitle: titulo,
        ),
      ),
    );
  }

  /// Apaga los dos recordatorios — se llama al desactivar el interruptor.
  static Future<void> cancelarTodos() async {
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
