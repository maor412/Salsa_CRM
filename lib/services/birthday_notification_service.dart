import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'firestore_service.dart';
import '../models/student_model.dart';

class BirthdayNotificationService {
  static final BirthdayNotificationService _instance =
      BirthdayNotificationService._internal();
  factory BirthdayNotificationService() => _instance;
  BirthdayNotificationService._internal();

  final NotificationService _notificationService = NotificationService();
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> checkAndNotifyTodayBirthdays() async {
    await scheduleTodayBirthdayNotifications();
  }

  Future<void> scheduleTodayBirthdayNotifications() async {
    try {
      final todayBirthdayStudents =
          await _firestoreService.getTodayBirthdayStudents();

      if (todayBirthdayStudents.isEmpty) {
        return;
      }

      final now = DateTime.now();
      final scheduledDate = DateTime(now.year, now.month, now.day, 9, 0);

      for (final student in todayBirthdayStudents) {
        final alreadyNotified = await _wasNotifiedToday(student.id);

        if (alreadyNotified) {
          continue;
        }

        if (now.isAfter(scheduledDate)) {
          await _sendBirthdayNotification(student);
        } else {
          await _notificationService.scheduleNotification(
            id: _notificationIdForStudent(student.id, scheduledDate),
            title:
                '\u05d9\u05e9 \u05d9\u05d5\u05dd \u05d4\u05d5\u05dc\u05d3\u05ea \u05d4\u05d9\u05d5\u05dd',
            body:
                '\u05dc${student.name} \u05d9\u05e9 \u05d9\u05d5\u05dd \u05d4\u05d5\u05dc\u05d3\u05ea \u05d4\u05d9\u05d5\u05dd, \u05ea\u05d1\u05e8\u05db\u05d5 \u05d0\u05d5\u05ea\u05d5 \u05d1-WhatsApp!',
            scheduledDate: scheduledDate,
            payload: 'birthday_${student.id}',
          );
        }

        await _markAsNotifiedToday(student.id);
      }
    } catch (e) {
      print('Error checking birthday notifications: $e');
    }
  }

  Future<void> _sendBirthdayNotification(StudentModel student) async {
    try {
      await _notificationService.showInstantNotification(
        title:
            '\u05d9\u05e9 \u05d9\u05d5\u05dd \u05d4\u05d5\u05dc\u05d3\u05ea \u05d4\u05d9\u05d5\u05dd',
        body:
            '\u05dc${student.name} \u05d9\u05e9 \u05d9\u05d5\u05dd \u05d4\u05d5\u05dc\u05d3\u05ea \u05d4\u05d9\u05d5\u05dd, \u05ea\u05d1\u05e8\u05db\u05d5 \u05d0\u05d5\u05ea\u05d5 \u05d1-WhatsApp!',
        payload: 'birthday_${student.id}',
      );
    } catch (e) {
      print('Error sending birthday notification for ${student.name}: $e');
    }
  }

  Future<bool> _wasNotifiedToday(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayKey();
      final key = 'birthday_notified_${studentId}_$today';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      print('Error checking notification status: $e');
      return false;
    }
  }

  Future<void> _markAsNotifiedToday(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayKey();
      final key = 'birthday_notified_${studentId}_$today';
      await prefs.setBool(key, true);

      await _cleanOldNotifications(prefs);
    } catch (e) {
      print('Error marking notification: $e');
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int _notificationIdForStudent(String studentId, DateTime date) {
    final key = '${studentId}_${date.year}-${date.month}-${date.day}';
    return key.hashCode & 0x7fffffff;
  }

  Future<void> _cleanOldNotifications(SharedPreferences prefs) async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('birthday_notified_')) {
          final parts = key.split('_');
          if (parts.length >= 4) {
            final dateStr = parts[3];
            try {
              final date = DateTime.parse(dateStr);
              if (date.isBefore(weekAgo)) {
                await prefs.remove(key);
              }
            } catch (e) {
              await prefs.remove(key);
            }
          }
        }
      }
    } catch (e) {
      print('Error cleaning old notifications: $e');
    }
  }
}
