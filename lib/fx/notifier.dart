import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../model/habit.dart';
import '../model/nudge.dart';

/// El teléfono. Todo lo que decide **cuándo** y **qué** está en
/// `model/nudge.dart`; aquí sólo se programa lo que aquél dijo.
///
/// La separación no es por gusto: lo único que puede salir mal de verdad en una
/// notificación es la decisión, y la decisión se puede probar sin teléfono. Lo
/// de acá no se puede probar de ninguna manera que valga —un test no recibe
/// notificaciones— así que cuanto menos haya, mejor.
///
/// **Se reprograma entero cada vez.** Al abrir la app, al cerrarla y cada vez
/// que cae una pieza: se borra todo lo pendiente y se vuelve a programar desde
/// cero. Es más barato que llevar la cuenta de qué hay puesto, y es lo único
/// que garantiza que poner una pieza cancele el aviso que iba a decirte que
/// hace días que no ponés ninguna.
class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();

  final _plug = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Si el sistema nos deja avisar. Nulo mientras no se haya preguntado.
  bool? _allowed;
  bool get allowed => _allowed ?? false;

  static const _channel = AndroidNotificationChannel(
    'pueblo',
    'Tu pueblo',
    description:
        'Avisos cuando llevás más de lo tuyo sin poner una pieza. Como mucho '
        'dos por ausencia, y ninguno si no te retrasás.',
    importance: Importance.defaultImportance,
  );

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plug.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _plug
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    _ready = true;
  }

  /// Pide permiso, si hace falta pedirlo.
  ///
  /// Se pregunta cuando alguien enciende el interruptor en ajustes y no al
  /// abrir la app por primera vez. Un permiso pedido antes de que se sepa para
  /// qué es se contesta que no, y con razón.
  Future<bool> ask() async {
    await _init();
    try {
      final android = _plug
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        _allowed = await android.requestNotificationsPermission() ?? false;
        return _allowed!;
      }
      final ios = _plug
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      _allowed =
          await ios?.requestPermissions(alert: true, sound: true) ?? false;
      return _allowed!;
    } catch (_) {
      _allowed = false;
      return false;
    }
  }

  /// Borra lo pendiente y programa lo que toque.
  ///
  /// [on] apagado borra y no programa nada, que es lo que tiene que pasar en
  /// cuanto alguien apaga el interruptor: no esperar a que caduque lo que ya
  /// estaba puesto.
  Future<void> reschedule(
    List<Habit> habits,
    DateTime now, {
    required bool on,
    DateTime? lastAny,
  }) async {
    await _init();
    try {
      await _plug.cancelAll();
      if (!on) return;
      final quedan = planAhead(habits, now, lastAny: lastAny);
      for (var i = 0; i < quedan.length; i++) {
        await _schedule(i, quedan[i]);
      }
    } catch (_) {
      // Un aviso es un extra. Si el sistema no deja programarlo, la app sigue
      // funcionando igual: es lo mismo que tenerlos apagados.
    }
  }

  Future<void> _schedule(int id, Nudge n) async {
    await _plug.zonedSchedule(
      id: id,
      title: n.title,
      body: n.body,
      scheduledDate: tz.TZDateTime.from(n.at, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // El cuerpo es de dos renglones cuando lleva tus dos frases, y sin
          // esto Android enseña el primero y corta.
          styleInformation: BigTextStyleInformation(n.body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Borra todo. Para cuando se apagan desde ajustes.
  Future<void> clear() async {
    await _init();
    try {
      await _plug.cancelAll();
    } catch (_) {}
  }
}
