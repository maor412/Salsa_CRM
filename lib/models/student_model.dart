import 'package:cloud_firestore/cloud_firestore.dart';

/// מודל תלמיד
class StudentModel {
  final String id;
  final String name;
  final String phoneNumber;
  final DateTime? birthday;
  final DateTime joinedAt;
  final bool isActive;
  final String? notes;

  StudentModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.birthday,
    required this.joinedAt,
    this.isActive = true,
    this.notes,
  });

  /// המרה מ-Firestore
  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentModel(
      id: doc.id,
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      birthday: (data['birthday'] as Timestamp?)?.toDate(),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      notes: data['notes'],
    );
  }

  /// המרה ל-Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isActive': isActive,
      'notes': notes,
    };
  }

  /// העתקה עם שינויים
  StudentModel copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    DateTime? birthday,
    DateTime? joinedAt,
    bool? isActive,
    String? notes,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthday: birthday ?? this.birthday,
      joinedAt: joinedAt ?? this.joinedAt,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }

  /// בדיקה האם יש יום הולדת בטווח של ±daysRange ימים
  /// עובד נכון גם סביב סוף/תחילת שנה (דצמבר/ינואר)
  bool hasBirthdayInRange(DateTime date, {int daysRange = 3}) {
    if (birthday == null) return false;

    // בדיקה אם יום הולדת (חודש+יום) נמצא בטווח
    for (int i = -daysRange; i <= daysRange; i++) {
      final checkDate = date.add(Duration(days: i));

      if (checkDate.month == birthday!.month && checkDate.day == birthday!.day) {
        return true;
      }
    }

    return false;
  }

  /// בדיקה האם יום הולדת היום בדיוק
  bool isBirthdayToday(DateTime date) {
    if (birthday == null) return false;
    return date.month == birthday!.month && date.day == birthday!.day;
  }

  /// קבלת טקסט ברכה ליום הולדת
  String getBirthdayGreeting() {
    return name;
  }
}
