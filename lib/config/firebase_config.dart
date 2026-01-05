/// קובץ זה יכיל את ההגדרות של Firebase
/// יש להריץ את הפקודה הבאה ליצירת הקובץ firebase_options.dart:
///
/// flutterfire configure
///
/// הפקודה תיצור את הקובץ firebase_options.dart עם ההגדרות הנדרשות
/// לאחר יצירת פרויקט ב-Firebase Console

class FirebaseConfig {
  // Collection names
  static const String usersCollection = 'users';
  static const String studentsCollection = 'students';
  static const String attendanceSessionsCollection = 'attendanceSessions';
  static const String attendanceRecordsCollection = 'attendanceRecords';
  static const String exercisesCollection = 'exercises';
  static const String messageTemplatesCollection = 'messageTemplates';
  static const String messageEventsCollection = 'messageEvents';
  static const String settingsCollection = 'settings';
  static const String shinesCollection = 'shinesExercises';

  // Settings document IDs
  static const String whatsappSettingsDoc = 'whatsapp';
}
