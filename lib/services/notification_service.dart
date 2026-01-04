import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _initializeTimeZone();

    await _requestPushPermissions();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  Future<void> _initializeTimeZone() async {
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final timeZoneName = timeZoneInfo.identifier;
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      tz.initializeTimeZones();
      print('Error initializing time zone: $e');
    }
  }

  Future<void> _requestPushPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Push notifications permission granted');

      try {
        final token = await _fcm.getToken();
        print('FCM Token: $token');
      } catch (e) {
        print('Error getting FCM token: $e');
      }
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message: ${message.notification?.title}');

    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? '',
        body: message.notification!.body ?? '',
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Notification opened: ${message.data}');
  }

  void _onNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'salsa_crm_channel',
      'Salsa CRM Notifications',
      channelDescription: 'Local notifications for Salsa CRM',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'salsa_crm_scheduled',
      'Scheduled Notifications',
      channelDescription: 'Scheduled notifications for Salsa CRM',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  Future<void> scheduleWeeklyMessageReminders() async {
    await _scheduleWeeklyReminder(
      id: 1,
      dayOfWeek: DateTime.wednesday,
      hour: 9,
      minute: 30,
      title:
          '\u05ea\u05d6\u05db\u05d5\u05e8\u05ea \u05dc\u05e9\u05dc\u05d9\u05d7\u05ea \u05d4\u05d5\u05d3\u05e2\u05d4 \u05d1\u05e7\u05d1\u05d5\u05e6\u05d4',
      body:
          '\u05d0\u05dc \u05ea\u05e9\u05db\u05d7 \u05dc\u05e9\u05dc\u05d5\u05d7 \u05d4\u05d5\u05d3\u05e2\u05d4 \u05d1\u05e7\u05d1\u05d5\u05e6\u05ea \u05d4-WhatsApp',
    );

    await _scheduleWeeklyReminder(
      id: 2,
      dayOfWeek: DateTime.saturday,
      hour: 9,
      minute: 30,
      title:
          '\u05ea\u05d6\u05db\u05d5\u05e8\u05ea \u05dc\u05e9\u05dc\u05d9\u05d7\u05ea \u05d4\u05d5\u05d3\u05e2\u05d4 \u05d1\u05e7\u05d1\u05d5\u05e6\u05d4',
      body:
          '\u05d0\u05dc \u05ea\u05e9\u05db\u05d7 \u05dc\u05e9\u05dc\u05d5\u05d7 \u05d4\u05d5\u05d3\u05e2\u05d4 \u05d1\u05e7\u05d1\u05d5\u05e6\u05ea \u05d4-WhatsApp',
    );
  }

  Future<void> _scheduleWeeklyReminder({
    required int id,
    required int dayOfWeek,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    await scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
    );
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _showLocalNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }
}
