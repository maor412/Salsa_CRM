import 'package:cloud_firestore/cloud_firestore.dart';

/// מודל תרגיל
class ExerciseModel {
  final String id;
  final String name;
  final String description;
  final int orderIndex;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;

  ExerciseModel({
    required this.id,
    required this.name,
    required this.description,
    required this.orderIndex,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
  });

  /// המרה מ-Firestore
  factory ExerciseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExerciseModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      orderIndex: data['orderIndex'] ?? 0,
      isCompleted: data['isCompleted'] ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// המרה ל-Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'orderIndex': orderIndex,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// העתקה עם שינויים
  ExerciseModel copyWith({
    String? id,
    String? name,
    String? description,
    int? orderIndex,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return ExerciseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// רשימת תרגילים מוגדרים מראש
class DefaultExercises {
  static final List<Map<String, dynamic>> exercises = [
    {
      'name': 'בסיסי - צעד קדימה ואחורה',
      'description': 'תרגול הצעד הבסיסי של סלסה',
      'orderIndex': 1,
    },
    {
      'name': 'סיבוב בסיסי ימינה',
      'description': 'סיבוב 360 מעלות ימינה',
      'orderIndex': 2,
    },
    {
      'name': 'סיבוב בסיסי שמאלה',
      'description': 'סיבוב 360 מעלות שמאלה',
      'orderIndex': 3,
    },
    {
      'name': 'Cross Body Lead',
      'description': 'תרגיל מעבר צולב',
      'orderIndex': 4,
    },
    {
      'name': 'Right Turn',
      'description': 'סיבוב ימני של הבת זוג',
      'orderIndex': 5,
    },
    {
      'name': 'Left Turn',
      'description': 'סיבוב שמאלי של הבת זוג',
      'orderIndex': 6,
    },
    {
      'name': 'Inside Turn',
      'description': 'סיבוב פנימי',
      'orderIndex': 7,
    },
    {
      'name': 'Outside Turn',
      'description': 'סיבוב חיצוני',
      'orderIndex': 8,
    },
    {
      'name': 'Copa',
      'description': 'תרגיל קופה',
      'orderIndex': 9,
    },
    {
      'name': 'Enchufla',
      'description': 'תרגיל אנצ\'ופלה',
      'orderIndex': 10,
    },
    {
      'name': 'Dile Que No',
      'description': 'תרגיל דילה קה נו',
      'orderIndex': 11,
    },
    {
      'name': 'Hammerlock',
      'description': 'תרגיל המרלוק',
      'orderIndex': 12,
    },
    {
      'name': 'Exhibela',
      'description': 'תרגיל אקסיבלה',
      'orderIndex': 13,
    },
    {
      'name': 'Sombrero',
      'description': 'תרגיל סומברו',
      'orderIndex': 14,
    },
    {
      'name': 'Setenta',
      'description': 'תרגיל סטנטה (70)',
      'orderIndex': 15,
    },
  ];
}
