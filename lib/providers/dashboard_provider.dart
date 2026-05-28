import 'package:flutter/foundation.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';

/// נתונים עבור Dashboard
class DashboardData {
  final double lastSessionAttendanceRate;
  final int studentsWithThreeAbsences;
  final List<StudentAbsenceInfo> studentsWithConsecutiveAbsences;
  final double exercisesProgress;
  final List<String> alerts;
  final List<StudentModel> birthdayStudents;
  final String currentExerciseLevel; // הרמה הנוכחית של התרגילים

  DashboardData({
    required this.lastSessionAttendanceRate,
    required this.studentsWithThreeAbsences,
    required this.studentsWithConsecutiveAbsences,
    required this.exercisesProgress,
    required this.alerts,
    required this.birthdayStudents,
    this.currentExerciseLevel = '',
  });

  factory DashboardData.empty() {
    return DashboardData(
      lastSessionAttendanceRate: 0.0,
      studentsWithThreeAbsences: 0,
      studentsWithConsecutiveAbsences: const [],
      exercisesProgress: 0.0,
      alerts: [],
      birthdayStudents: [],
      currentExerciseLevel: '',
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
class _DashboardAttendanceSummary {
  final double lastSessionAttendanceRate;
  final List<StudentAbsenceInfo> studentsWithConsecutiveAbsences;

  const _DashboardAttendanceSummary({
    required this.lastSessionAttendanceRate,
    required this.studentsWithConsecutiveAbsences,
  });
}

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
      final students = await _firestoreService.getActiveStudents().first;
      final results = await Future.wait<Object>([
        _getAttendanceSummary(students),
        _getExercisesProgressAndLevel(),
        Future.value(_getBirthdayStudents(students)),
      ]);

      final attendanceSummary = results[0] as _DashboardAttendanceSummary;
      final absences = attendanceSummary.studentsWithConsecutiveAbsences;
      final exercisesData = results[1] as Map<String, dynamic>;
      final birthdayStudents = results[2] as List<StudentModel>;
      final alerts = await _generateAlerts(
        studentsWithAbsences: absences.length,
        birthdayStudents: birthdayStudents,
      );

      _data = DashboardData(
        lastSessionAttendanceRate: attendanceSummary.lastSessionAttendanceRate,
        studentsWithThreeAbsences: absences.length,
        studentsWithConsecutiveAbsences: absences,
        exercisesProgress: exercisesData['progress'] as double,
        alerts: alerts,
        birthdayStudents: birthdayStudents,
        currentExerciseLevel: exercisesData['currentLevel'] as String,
      );
    } catch (e) {
      print('Error loading dashboard data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// חישוב אחוז הגעה לשיעור האחרון
  Future<_DashboardAttendanceSummary> _getAttendanceSummary(
    List<StudentModel> students,
  ) async {
    try {
      final sessions =
          await _firestoreService.getRecentAttendanceSessionsOnce(limit: 2);

      if (sessions.isEmpty) {
        return const _DashboardAttendanceSummary(
          lastSessionAttendanceRate: 0.0,
          studentsWithConsecutiveAbsences: [],
        );
      }

      final sessionIds = sessions.map((session) => session.id).toList();
      final records =
          await _firestoreService.getAttendanceRecordsBySessions(sessionIds);

      final lastSessionId = sessions.first.id;
      final lastSessionRecords =
          records.where((record) => record.sessionId == lastSessionId).toList();

      final attendanceRate = lastSessionRecords.isEmpty
          ? 0.0
          : (lastSessionRecords.where((record) => record.attended).length /
                  lastSessionRecords.length) *
              100;

      final recordsByStudent = <String, Map<String, bool>>{};
      for (final record in records) {
        recordsByStudent.putIfAbsent(
          record.studentId,
          () => <String, bool>{},
        )[record.sessionId] = record.attended;
      }

      final results = <StudentAbsenceInfo>[];

      for (final student in students) {
        final studentAttendance = recordsByStudent[student.id] ?? {};
        var consecutiveAbsences = 0;

        for (final sessionId in sessionIds) {
          final didAttend = studentAttendance[sessionId] ?? false;
          if (didAttend) {
            break;
          }
          consecutiveAbsences++;
        }

        if (consecutiveAbsences >= 2) {
          results.add(StudentAbsenceInfo(
            student: student,
            consecutiveAbsences: consecutiveAbsences,
          ));
        }
      }

      results.sort(
        (a, b) => b.consecutiveAbsences.compareTo(a.consecutiveAbsences),
      );
      return _DashboardAttendanceSummary(
        lastSessionAttendanceRate: attendanceRate,
        studentsWithConsecutiveAbsences: results,
      );
    } catch (e) {
      print('Error calculating attendance summary: $e');
      return const _DashboardAttendanceSummary(
        lastSessionAttendanceRate: 0.0,
        studentsWithConsecutiveAbsences: [],
      );
    }
  }

  /// חישוב אחוז התקדמות בתרגילים והרמה הנוכחית
  Future<Map<String, dynamic>> _getExercisesProgressAndLevel() async {
    try {
      final exercises = await _firestoreService.getExercises().first;

      if (exercises.isEmpty) {
        return {'progress': 0.0, 'currentLevel': ''};
      }

      final completed = exercises.where((e) => e.isCompleted).length;
      final progress = (completed / exercises.length) * 100;

      final nextExercise = exercises.firstWhere(
        (e) => !e.isCompleted,
        orElse: () => exercises.last,
      );

      return {
        'progress': progress,
        'currentLevel': nextExercise.level,
      };
    } catch (e) {
      print('Error calculating exercises progress: $e');
      return {'progress': 0.0, 'currentLevel': ''};
    }
  }

  List<StudentModel> _getBirthdayStudents(List<StudentModel> students) {
    final now = DateTime.now();
    return students
        .where((student) => student.hasBirthdayInRange(now, daysRange: 3))
        .toList();
  }

  /// יצירת התראות
  Future<List<String>> _generateAlerts({
    required int studentsWithAbsences,
    required List<StudentModel> birthdayStudents,
  }) async {
    final alerts = <String>[];

    // התראה על תלמידים עם היעדרויות
    if (studentsWithAbsences > 0) {
      alerts.add('$studentsWithAbsences תלמידים לא הגיעו 2 פעמים ברצף');
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
