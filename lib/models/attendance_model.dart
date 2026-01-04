import 'package:cloud_firestore/cloud_firestore.dart';

/// סוגי שיעורים
enum LessonType {
  regular,
  pace,
  afro,
  pachanga,
  laPrep,
  shines,
}

/// מודל מפגש נוכחות
class AttendanceSession {
  final String id;
  final DateTime date;
  final LessonType lessonType;
  final String instructorId;
  final String instructorName;
  final DateTime createdAt;

  AttendanceSession({
    required this.id,
    required this.date,
    required this.lessonType,
    required this.instructorId,
    required this.instructorName,
    required this.createdAt,
  });

  /// המרה מ-Firestore
  factory AttendanceSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceSession(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      lessonType: LessonType.values.firstWhere(
        (e) => e.name == data['lessonType'],
        orElse: () => LessonType.regular,
      ),
      instructorId: data['instructorId'] ?? '',
      instructorName: data['instructorName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// המרה ל-Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'lessonType': lessonType.name,
      'instructorId': instructorId,
      'instructorName': instructorName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// שם סוג השיעור בעברית
  String get lessonTypeName {
    switch (lessonType) {
      case LessonType.regular:
        return 'רגיל';
      case LessonType.pace:
        return 'קצב';
      case LessonType.afro:
        return 'אפרו';
      case LessonType.pachanga:
        return 'פצ\'אנגה';
      case LessonType.laPrep:
        return 'הכנה ל-LA';
      case LessonType.shines:
        return 'הפלות';
    }
  }
}

/// מודל רשומת נוכחות לתלמיד
class AttendanceRecord {
  final String id;
  final String sessionId;
  final String studentId;
  final String studentName;
  final bool attended;
  final DateTime createdAt;

  AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.attended,
    required this.createdAt,
  });

  /// המרה מ-Firestore
  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceRecord(
      id: doc.id,
      sessionId: data['sessionId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      attended: data['attended'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// המרה ל-Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'sessionId': sessionId,
      'studentId': studentId,
      'studentName': studentName,
      'attended': attended,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// העתקה עם שינויים
  AttendanceRecord copyWith({
    String? id,
    String? sessionId,
    String? studentId,
    String? studentName,
    bool? attended,
    DateTime? createdAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      attended: attended ?? this.attended,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
