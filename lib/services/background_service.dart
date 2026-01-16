import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'notification_service.dart';
import 'birthday_notification_service.dart';

/// שירות לניהול משימות רקע
/// משתמש ב-Workmanager כדי להריץ משימות גם כשהאפליקציה סגורה
class BackgroundService {
  static const String _birthdayCheckTask = 'birthdayCheck';
  static const String _weeklyReminderTask = 'weeklyReminder';

  /// אתחול שירות הרקע
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    // תזמון בדיקת ימי הולדת - כל יום בשעה 9:00
    await scheduleDailyBirthdayCheck();

    // תזמון תזכורות שבועיות - רביעי ושבת
    await scheduleWeeklyReminders();
  }

  /// תזמון בדיקת ימי הולדת יומית
  static Future<void> scheduleDailyBirthdayCheck() async {
    await Workmanager().registerPeriodicTask(
      _birthdayCheckTask,
      _birthdayCheckTask,
      frequency: const Duration(hours: 24),
      initialDelay: _calculateInitialDelay(hour: 9, minute: 0),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  /// תזמון תזכורות שבועיות
  static Future<void> scheduleWeeklyReminders() async {
    // תזכורת רביעי - זמנית שונה לשישי 12:10 לבדיקה
    await Workmanager().registerPeriodicTask(
      '${_weeklyReminderTask}_wednesday',
      _weeklyReminderTask,
      frequency: const Duration(days: 7),
      initialDelay: _calculateWeeklyDelay(
        dayOfWeek: DateTime.friday,
        hour: 12,
        minute: 10,
      ),
      inputData: {'day': 'wednesday'},
      tag: 'wednesday_reminder',
    );

    // תזכורת שבת - זמנית שונה לשישי 12:10 לבדיקה
    await Workmanager().registerPeriodicTask(
      '${_weeklyReminderTask}_saturday',
      _weeklyReminderTask,
      frequency: const Duration(days: 7),
      initialDelay: _calculateWeeklyDelay(
        dayOfWeek: DateTime.friday,
        hour: 12,
        minute: 10,
      ),
      inputData: {'day': 'saturday'},
      tag: 'saturday_reminder',
    );
  }

  /// חישוב דחייה ראשונית ליום מסוים בשבוע
  static Duration _calculateWeeklyDelay({
    required int dayOfWeek,
    required int hour,
    required int minute,
  }) {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // מצא את היום הבא בשבוע
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // אם העבר את השעה היום, קפוץ לשבוע הבא
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    return scheduledDate.difference(now);
  }

  /// חישוב דחייה ראשונית לשעה מסוימת ביום
  static Duration _calculateInitialDelay({
    required int hour,
    required int minute,
  }) {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // אם עברה השעה היום, קבע למחר
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate.difference(now);
  }

  /// ביטול כל המשימות
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}

/// Callback שרץ ברקע
/// חשוב: פונקציה זו חייבת להיות top-level function (לא בתוך class)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('Background task started: $task');

      // אתחול Firebase (נדרש לכל משימת רקע)
      await Firebase.initializeApp();

      switch (task) {
        case BackgroundService._birthdayCheckTask:
          await _handleBirthdayCheck();
          break;

        case BackgroundService._weeklyReminderTask:
          await _handleWeeklyReminder(inputData);
          break;

        default:
          print('Unknown task: $task');
      }

      print('Background task completed: $task');
      return Future.value(true);
    } catch (e) {
      print('Background task error: $e');
      return Future.value(false);
    }
  });
}

/// טיפול בבדיקת ימי הולדת
Future<void> _handleBirthdayCheck() async {
  try {
    await NotificationService().initialize();
    await BirthdayNotificationService().scheduleTodayBirthdayNotifications();
    print('Birthday check completed successfully');
  } catch (e) {
    print('Error in birthday check: $e');
  }
}

/// טיפול בתזכורת שבועית
Future<void> _handleWeeklyReminder(Map<String, dynamic>? inputData) async {
  try {
    final day = inputData?['day'] ?? 'unknown';
    print('Sending weekly reminder for: $day');

    await NotificationService().initialize();
    await NotificationService().showInstantNotification(
      title: 'תזכורת לשליחת הודעה בקבוצה',
      body: 'אל תשכח לשלוח הודעה בקבוצת ה-WhatsApp',
    );

    print('Weekly reminder sent for: $day');
  } catch (e) {
    print('Error in weekly reminder: $e');
  }
}
