import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'notification_service.dart';
import 'birthday_notification_service.dart';

/// שירות לניהול משימות רקע
/// משתמש ב-Workmanager כדי להריץ משימות גם כשהאפליקציה סגורה
class BackgroundService {
  static const String _birthdayCheckTask = 'birthdayCheck';

  /// אתחול שירות הרקע
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    // תזמון בדיקת ימי הולדת - כל יום בשעה 9:00
    await scheduleDailyBirthdayCheck();
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
    // אתחול Workmanager לפני הביטול (נדרש כדי שה-cancelAll יעבוד)
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    // ביטול כל המשימות הרשומות
    await Workmanager().cancelAll();
  }
}

/// Callback שרץ ברקע - מבוטל! Firebase Functions מטפל בכל הנוטיפיקציות
/// חשוב: פונקציה זו חייבת להיות top-level function (לא בתוך class)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('⚠️ Background task ignored (disabled): $task');
    print('Firebase Functions handles all notifications now');
    // לא מבצעים שום פעולה - Firebase Functions מטפל בהכל
    return Future.value(true);
  });
}
