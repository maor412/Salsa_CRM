import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../models/exercise_model.dart';
import '../models/message_model.dart';
import '../config/firebase_config.dart';

/// שירות לניהול נתונים ב-Firestore
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== Students ==========

  /// הוספת תלמיד
  Future<String> addStudent(StudentModel student) async {
    final doc = await _firestore
        .collection(FirebaseConfig.studentsCollection)
        .add(student.toFirestore());
    return doc.id;
  }

  /// עדכון תלמיד
  Future<void> updateStudent(StudentModel student) async {
    await _firestore
        .collection(FirebaseConfig.studentsCollection)
        .doc(student.id)
        .update(student.toFirestore());
  }

  /// מחיקת תלמיד (השבתה)
  Future<void> deleteStudent(String studentId) async {
    await _firestore
        .collection(FirebaseConfig.studentsCollection)
        .doc(studentId)
        .update({'isActive': false});
  }

  /// קבלת כל התלמידים הפעילים
  Stream<List<StudentModel>> getActiveStudents() {
    return _firestore
        .collection(FirebaseConfig.studentsCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StudentModel.fromFirestore(doc))
            .toList());
  }

  /// קבלת תלמידים עם יום הולדת בטווח
  Future<List<StudentModel>> getStudentsWithBirthdayInRange(
    DateTime date, {
    int daysRange = 3,
  }) async {
    final students = await _firestore
        .collection(FirebaseConfig.studentsCollection)
        .where('isActive', isEqualTo: true)
        .get();

    return students.docs
        .map((doc) => StudentModel.fromFirestore(doc))
        .where((student) => student.hasBirthdayInRange(date, daysRange: daysRange))
        .toList();
  }

  /// קבלת תלמידים עם יום הולדת היום
  Future<List<StudentModel>> getTodayBirthdayStudents() async {
    final today = DateTime.now();
    final students = await _firestore
        .collection(FirebaseConfig.studentsCollection)
        .where('isActive', isEqualTo: true)
        .get();

    return students.docs
        .map((doc) => StudentModel.fromFirestore(doc))
        .where((student) => student.isBirthdayToday(today))
        .toList();
  }

  /// קבלת תלמידים עם יום הולדת קרוב (±3 ימים)
  Future<List<StudentModel>> getUpcomingBirthdayStudents() async {
    final today = DateTime.now();
    final students = await _firestore
        .collection(FirebaseConfig.studentsCollection)
        .where('isActive', isEqualTo: true)
        .get();

    return students.docs
        .map((doc) => StudentModel.fromFirestore(doc))
        .where((student) => student.hasBirthdayInRange(today, daysRange: 3))
        .toList();
  }

  // ========== Attendance ==========

  /// יצירת מפגש נוכחות
  Future<String> createAttendanceSession(AttendanceSession session) async {
    final doc = await _firestore
        .collection(FirebaseConfig.attendanceSessionsCollection)
        .add(session.toFirestore());
    return doc.id;
  }

  /// שמירת רשומות נוכחות
  Future<void> saveAttendanceRecords(List<AttendanceRecord> records) async {
    final batch = _firestore.batch();

    for (final record in records) {
      final docRef = _firestore
          .collection(FirebaseConfig.attendanceRecordsCollection)
          .doc();
      batch.set(docRef, record.copyWith(id: docRef.id).toFirestore());
    }

    await batch.commit();
  }

  /// קבלת מפגשי נוכחות אחרונים
  Stream<List<AttendanceSession>> getRecentAttendanceSessions({int limit = 10}) {
    return _firestore
        .collection(FirebaseConfig.attendanceSessionsCollection)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AttendanceSession.fromFirestore(doc))
            .toList());
  }

  /// קבלת רשומות נוכחות לפי מפגש
  Future<List<AttendanceRecord>> getAttendanceRecordsBySession(
    String sessionId,
  ) async {
    final snapshot = await _firestore
        .collection(FirebaseConfig.attendanceRecordsCollection)
        .where('sessionId', isEqualTo: sessionId)
        .get();

    return snapshot.docs
        .map((doc) => AttendanceRecord.fromFirestore(doc))
        .toList();
  }

  /// חישוב סטטיסטיקות נוכחות לתלמיד
  Future<Map<String, dynamic>> getStudentAttendanceStats(
    String studentId, {
    int lastNSessions = 10,
  }) async {
    // קבלת המפגשים האחרונים
    final sessions = await _firestore
        .collection(FirebaseConfig.attendanceSessionsCollection)
        .orderBy('date', descending: true)
        .limit(lastNSessions)
        .get();

    if (sessions.docs.isEmpty) {
      return {
        'attendanceRate': 0.0,
        'consecutiveAbsences': 0,
        'totalSessions': 0,
        'attended': 0,
      };
    }

    final sessionIds = sessions.docs.map((doc) => doc.id).toList();

    // קבלת רשומות נוכחות לתלמיד
    final records = await _firestore
        .collection(FirebaseConfig.attendanceRecordsCollection)
        .where('studentId', isEqualTo: studentId)
        .where('sessionId', whereIn: sessionIds)
        .get();

    final attendanceMap = {
      for (var doc in records.docs)
        (doc.data()['sessionId'] as String): doc.data()['attended'] as bool
    };

    int attended = 0;
    int consecutiveAbsences = 0;

    for (final sessionId in sessionIds) {
      final didAttend = attendanceMap[sessionId] ?? false;
      if (didAttend) {
        attended++;
        consecutiveAbsences = 0;
      } else {
        consecutiveAbsences++;
      }
    }

    return {
      'attendanceRate': sessionIds.isEmpty ? 0.0 : (attended / sessionIds.length) * 100,
      'consecutiveAbsences': consecutiveAbsences,
      'totalSessions': sessionIds.length,
      'attended': attended,
    };
  }

  // ========== Exercises ==========

  /// קבלת כל התרגילים
  Stream<List<ExerciseModel>> getExercises() {
    return _firestore
        .collection(FirebaseConfig.exercisesCollection)
        .orderBy('orderIndex')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExerciseModel.fromFirestore(doc))
            .toList());
  }

  /// עדכון סטטוס תרגיל
  Future<void> updateExerciseStatus(String exerciseId, bool isCompleted) async {
    await _firestore
        .collection(FirebaseConfig.exercisesCollection)
        .doc(exerciseId)
        .update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? Timestamp.now() : null,
    });
  }

  /// איתחול תרגילים מוגדרים מראש
  Future<void> initializeDefaultExercises() async {
    final existingExercises = await _firestore
        .collection(FirebaseConfig.exercisesCollection)
        .limit(1)
        .get();

    if (existingExercises.docs.isEmpty) {
      final batch = _firestore.batch();

      for (final exerciseData in DefaultExercises.exercises) {
        final docRef = _firestore
            .collection(FirebaseConfig.exercisesCollection)
            .doc();

        final exercise = ExerciseModel(
          id: docRef.id,
          name: exerciseData['name'],
          description: exerciseData['description'],
          orderIndex: exerciseData['orderIndex'],
          createdAt: DateTime.now(),
          videoUrl: exerciseData['videoUrl'],
          level: exerciseData['level'] ?? 'רמת בסיס',
        );

        batch.set(docRef, exercise.toFirestore());
      }

      await batch.commit();
    }
  }

  /// מחיקה ואיתחול מחדש של כל התרגילים
  Future<void> resetExercises() async {
    // מחיקת כל התרגילים הקיימים
    final existingExercises = await _firestore
        .collection(FirebaseConfig.exercisesCollection)
        .get();

    final batch = _firestore.batch();

    // מחיקת כל התרגילים הישנים
    for (final doc in existingExercises.docs) {
      batch.delete(doc.reference);
    }

    // הוספת התרגילים החדשים
    for (final exerciseData in DefaultExercises.exercises) {
      final docRef = _firestore
          .collection(FirebaseConfig.exercisesCollection)
          .doc();

      final exercise = ExerciseModel(
        id: docRef.id,
        name: exerciseData['name'],
        description: exerciseData['description'],
        orderIndex: exerciseData['orderIndex'],
        createdAt: DateTime.now(),
        videoUrl: exerciseData['videoUrl'],
        level: exerciseData['level'] ?? 'רמת בסיס',
      );

      batch.set(docRef, exercise.toFirestore());
    }

    await batch.commit();
    print('✅ Exercises reset successfully!');
  }

  // ========== Message Templates ==========

  /// הוספת תבנית הודעה
  Future<String> addMessageTemplate(MessageTemplate template) async {
    final doc = await _firestore
        .collection(FirebaseConfig.messageTemplatesCollection)
        .add(template.toFirestore());
    return doc.id;
  }

  /// עדכון תבנית הודעה
  Future<void> updateMessageTemplate(MessageTemplate template) async {
    await _firestore
        .collection(FirebaseConfig.messageTemplatesCollection)
        .doc(template.id)
        .update(template.toFirestore());
  }

  /// קבלת תבניות לפי קטגוריה
  Future<List<MessageTemplate>> getTemplatesByCategory(
    MessageCategory category,
  ) async {
    final snapshot = await _firestore
        .collection(FirebaseConfig.messageTemplatesCollection)
        .where('category', isEqualTo: category.name)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => MessageTemplate.fromFirestore(doc))
        .toList();
  }

  /// קבלת כל התבניות (Admin)
  Stream<List<MessageTemplate>> getAllTemplates() {
    return _firestore
        .collection(FirebaseConfig.messageTemplatesCollection)
        .orderBy('category')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageTemplate.fromFirestore(doc))
            .toList());
  }

  // ========== Message Events ==========

  /// יצירת אירוע הודעה
  Future<String> createMessageEvent(MessageEvent event) async {
    final doc = await _firestore
        .collection(FirebaseConfig.messageEventsCollection)
        .add(event.toFirestore());
    return doc.id;
  }

  /// עדכון אירוע הודעה
  Future<void> updateMessageEvent(MessageEvent event) async {
    await _firestore
        .collection(FirebaseConfig.messageEventsCollection)
        .doc(event.id)
        .update(event.toFirestore());
  }

  /// קבלת אירוע הודעה לפי תאריך
  Future<MessageEvent?> getMessageEventByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection(FirebaseConfig.messageEventsCollection)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return MessageEvent.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  /// קבלת היסטוריית הודעות
  Stream<List<MessageEvent>> getMessageHistory({int limit = 50}) {
    return _firestore
        .collection(FirebaseConfig.messageEventsCollection)
        .orderBy('scheduledDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageEvent.fromFirestore(doc))
            .toList());
  }

  /// נעילת אירוע הודעה
  Future<bool> lockMessageEvent(
    String eventId,
    String userId,
    String userName,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final eventRef = _firestore
            .collection(FirebaseConfig.messageEventsCollection)
            .doc(eventId);

        final eventDoc = await transaction.get(eventRef);
        if (!eventDoc.exists) {
          throw Exception('Event not found');
        }

        final event = MessageEvent.fromFirestore(eventDoc);

        if (event.isLocked && !event.isLockedByUser(userId)) {
          throw Exception('Event already locked by another user');
        }

        transaction.update(eventRef, {
          'lockedBy': userId,
          'lockedByName': userName,
          'lockedAt': Timestamp.now(),
        });
      });
      return true;
    } catch (e) {
      print('Error locking event: $e');
      return false;
    }
  }
}
