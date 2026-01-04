import 'package:flutter/foundation.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../models/exercise_model.dart';
import '../models/message_model.dart';
import '../services/firestore_service.dart';

/// נתונים עבור Dashboard
class DashboardData {
  final double lastSessionAttendanceRate;
  final int studentsWithThreeAbsences;
  final List<StudentAbsenceInfo> studentsWithConsecutiveAbsences;
  final double exercisesProgress;
  final List<String> alerts;
  final List<StudentModel> birthdayStudents;

  DashboardData({
    required this.lastSessionAttendanceRate,
    required this.studentsWithThreeAbsences,
    required this.studentsWithConsecutiveAbsences,
    required this.exercisesProgress,
    required this.alerts,
    required this.birthdayStudents,
  });

  factory DashboardData.empty() {
    return DashboardData(
      lastSessionAttendanceRate: 0.0,
      studentsWithThreeAbsences: 0,
      studentsWithConsecutiveAbsences: const [],
      exercisesProgress: 0.0,
      alerts: [],
      birthdayStudents: [],
    );
  }
}

class StudentAbsenceInfo {
  final StudentModel student;
  final int consecutiveAbsences;

  const StudentAbsenceInfo({
    required this.student,
    required this.consecutiveAbsences,
  });
}

/// Provider לנתוני Dashboard
class DashboardProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  DashboardData _data = DashboardData.empty();
  bool _isLoading = false;

  DashboardData get data => _data;
  bool get isLoading => _isLoading;

  /// טעינת נתוני Dashboard
  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // קבלת כל הנתונים במקביל
      final results = await Future.wait([
        _getLastSessionAttendanceRate(),
        _getStudentsWithThreeAbsences(),
        _getExercisesProgress(),
        _getBirthdayStudents(),
      ]);

      final absences = results[1] as List<StudentAbsenceInfo>;
      final alerts = await _generateAlerts(
        studentsWithAbsences: absences.length,
        birthdayStudents: results[3] as List<StudentModel>,
      );

      _data = DashboardData(
        lastSessionAttendanceRate: results[0] as double,
        studentsWithThreeAbsences: absences.length,
        studentsWithConsecutiveAbsences: absences,
        exercisesProgress: results[2] as double,
        alerts: alerts,
        birthdayStudents: results[3] as List<StudentModel>,
      );
    } catch (e) {
      print('Error loading dashboard data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// חישוב אחוז הגעה לשיעור האחרון
  Future<double> _getLastSessionAttendanceRate() async {
    try {
      final sessions = await _firestoreService
          .getRecentAttendanceSessions(limit: 1)
          .first;

      if (sessions.isEmpty) return 0.0;

      final lastSession = sessions.first;
      final records = await _firestoreService
          .getAttendanceRecordsBySession(lastSession.id);

      if (records.isEmpty) return 0.0;

      final attended = records.where((r) => r.attended).length;
      return (attended / records.length) * 100;
    } catch (e) {
      print('Error calculating attendance rate: $e');
      return 0.0;
    }
  }

  /// ספירת תלמידים עם 3 היעדרויות רצופות
  Future<List<StudentAbsenceInfo>> _getStudentsWithThreeAbsences() async {
    try {
      final students = await _firestoreService.getActiveStudents().first;
      final results = <StudentAbsenceInfo>[];

      for (final student in students) {
        final stats = await _firestoreService.getStudentAttendanceStats(
          student.id,
          lastNSessions: 3,
        );

        final consecutiveAbsences = stats['consecutiveAbsences'] as int? ?? 0;
        if (consecutiveAbsences >= 3) {
          results.add(StudentAbsenceInfo(
            student: student,
            consecutiveAbsences: consecutiveAbsences,
          ));
        }
      }

      results.sort(
        (a, b) => b.consecutiveAbsences.compareTo(a.consecutiveAbsences),
      );
      return results;
    } catch (e) {
      print('Error counting students with absences: $e');
      return [];
    }
  }

  /// חישוב אחוז התקדמות בתרגילים
  Future<double> _getExercisesProgress() async {
    try {
      final exercises = await _firestoreService.getExercises().first;

      if (exercises.isEmpty) return 0.0;

      final completed = exercises.where((e) => e.isCompleted).length;
      return (completed / exercises.length) * 100;
    } catch (e) {
      print('Error calculating exercises progress: $e');
      return 0.0;
    }
  }

  /// קבלת תלמידים עם יום הולדת השבוע
  Future<List<StudentModel>> _getBirthdayStudents() async {
    try {
      return await _firestoreService.getStudentsWithBirthdayInRange(
        DateTime.now(),
        daysRange: 7,
      );
    } catch (e) {
      print('Error getting birthday students: $e');
      return [];
    }
  }

  /// יצירת התראות
  Future<List<String>> _generateAlerts({
    required int studentsWithAbsences,
    required List<StudentModel> birthdayStudents,
  }) async {
    final alerts = <String>[];

    // התראה על תלמידים עם היעדרויות
    if (studentsWithAbsences > 0) {
      alerts.add('$studentsWithAbsences תלמידים לא הגיעו 3 פעמים ברצף');
    }

    // בדיקה האם נשלחה הודעה היום
    final today = DateTime.now();
    final isWednesday = today.weekday == DateTime.wednesday;
    final isSaturday = today.weekday == DateTime.saturday;

    if (isWednesday || isSaturday) {
      final todayEvent = await _firestoreService.getMessageEventByDate(today);
      if (todayEvent == null || !todayEvent.isSent) {
        final dayName = isWednesday ? 'רביעי' : 'מוצ"ש';
        alerts.add('לא נשלחה הודעת היום ביילה ל$dayName');
      }
    }

    // התראה על ימי הולדת
    if (birthdayStudents.isNotEmpty) {
      alerts.add('יש יום הולדת השבוע ל-${birthdayStudents.length} תלמידים');
    }

    return alerts;
  }

  /// רענון נתונים
  Future<void> refresh() => loadDashboardData();
}
