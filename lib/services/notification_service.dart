import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    // יצירת ערוץ נוטיפיקציות לתזכורות שבועיות
    const AndroidNotificationChannel weeklyRemindersChannel =
        AndroidNotificationChannel(
      'weekly_reminders',
      'Weekly Reminders',
      description: 'Weekly message reminders from Firebase',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // יצירת ערוץ נוטיפיקציות לימי הולדת
    const AndroidNotificationChannel birthdaysChannel =
        AndroidNotificationChannel(
      'birthdays',
      'Birthday Reminders',
      description: 'Birthday notifications from Firebase',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(weeklyRemindersChannel);
    await androidPlugin?.createNotificationChannel(birthdaysChannel);

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
      print('🌍 Timezone initialized: $timeZoneName');
      print('🕐 Current local time: ${tz.TZDateTime.now(tz.local)}');
    } catch (e) {
      tz.initializeTimeZones();
      print('❌ Error initializing time zone: $e');
      print('⚠️ Using default timezone');
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

        // שמירת ה-token ב-Firestore (יישמר אוטומטית עבור המשתמש המחובר)
        if (token != null) {
          await _saveFCMToken(token);
        }

        // האזנה לשינויים ב-token
        _fcm.onTokenRefresh.listen(_saveFCMToken);
      } catch (e) {
        print('Error getting FCM token: $e');
      }
    }
  }

  Future<void> _saveFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
        print('✅ FCM token saved successfully');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
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
    print('📅 Scheduling notification:');
    print('  ID: $id');
    print('  Title: $title');
    print('  Scheduled for: $scheduledDate');
    print('  Current time: ${DateTime.now()}');
    print('  Time until notification: ${scheduledDate.difference(DateTime.now())}');

    const androidDetails = AndroidNotificationDetails(
      'salsa_crm_scheduled',
      'Scheduled Notifications',
      channelDescription: 'Scheduled notifications for Salsa CRM',
      importance: Importance.high,
      priority: Priority.high,
      enableLights: true,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      print('✅ Notification scheduled successfully!');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
      rethrow;
    }
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  Future<void> scheduleWeeklyMessageReminders() async {
    print('📅 Scheduling weekly message reminders...');

    // תזכורת רביעי - זמנית שונה לשישי 12:10 לבדיקה
    await _scheduleWeeklyReminder(
      id: 1,
      dayOfWeek: DateTime.friday,
      hour: 12,
      minute: 10,
      title:
          '\u05ea\u05d6\u05db\u05d5\u05e8\u05ea \u05dc\u05e9\u05dc\u05d9\u05d7\u05ea \u05d4\u05d5\u05d3\u05e2\u05d4 \u05d1\u05e7\u05d1\u05d5\u05e6\u05d4',
      body:
          '\u05d0\u05dc \u05ea\u05e9\u05db\u05d7 \u05dc\u05e9\u05dc\u05d5\u05d7 \u05d4\u05d5\u05d3\u05e2\u05d4 \u05d1\u05e7\u05d1\u05d5\u05e6\u05ea \u05d4-WhatsApp',
    );

    // תזכורת שבת - זמנית שונה לשישי 12:10 לבדיקה
    await _scheduleWeeklyReminder(
      id: 2,
      dayOfWeek: DateTime.friday,
      hour: 12,
      minute: 10,
      title:
          '\u05ea\u05d6\u05db\u05d5\u05e8\u05ea \u05dc\u05e9\u05dc\u05d9\u05d7\u05ea \u05d4\u05d5\u05d3\u05e2\u05d4 \u05d1\u05e7\u05d1\u05d5\u05e6\u05d4',
      body:
          '\u05d0\u05dc \u05ea\u05e9\u05db\u05d7 \u05dc\u05e9\u05dc\u05d5\u05d7 \u05d4\u05d5\u05d3\u05e2\u05d4 \u05d1\u05e7\u05d1\u05d5\u05e6\u05ea \u05d4-WhatsApp',
    );

    print('✅ Weekly reminders scheduled successfully!');
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

    print('📍 Calculating next $dayOfWeek at $hour:$minute');
    print('  Current time: $now');
    print('  Initial date: $scheduledDate');

    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    print('  Found weekday: $scheduledDate');

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
      print('  Time passed, moved to next week: $scheduledDate');
    }

    print('  Final scheduled date: $scheduledDate');

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
