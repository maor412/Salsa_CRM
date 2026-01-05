import 'package:cloud_firestore/cloud_firestore.dart';

/// מודל לפריט שיינס בודד
class ShinesItemModel {
  final String id;
  final String text;
  final int orderIndex;
  final DateTime createdAt;

  ShinesItemModel({
    required this.id,
    required this.text,
    required this.orderIndex,
    required this.createdAt,
  });

  /// יצירה מ-Firestore
  factory ShinesItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShinesItemModel(
      id: doc.id,
      text: data['text'] ?? '',
      orderIndex: data['orderIndex'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// המרה ל-Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'orderIndex': orderIndex,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// יצירת עותק עם שינויים
  ShinesItemModel copyWith({
    String? id,
    String? text,
    int? orderIndex,
    DateTime? createdAt,
  }) {
    return ShinesItemModel(
      id: id ?? this.id,
      text: text ?? this.text,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
