import 'package:cloud_firestore/cloud_firestore.dart';

/// קטגוריות הודעות
enum MessageCategory {
  regular,
  pace,
  afro,
  pachanga,
  laPrep,
  shines,
}

/// מודל תבנית הודעה
class MessageTemplate {
  final String id;
  final String content;
  final MessageCategory category;
  final bool isActive;
  final DateTime createdAt;
  final String? createdBy;

  MessageTemplate({
    required this.id,
    required this.content,
    required this.category,
    this.isActive = true,
    required this.createdAt,
    this.createdBy,
  });

  /// המרה מ-Firestore
  factory MessageTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageTemplate(
      id: doc.id,
      content: data['content'] ?? '',
      category: MessageCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => MessageCategory.regular,
      ),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
    );
  }

  /// המרה ל-Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'category': category.name,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  /// העתקה עם שינויים
  MessageTemplate copyWith({
    String? id,
    String? content,
    MessageCategory? category,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return MessageTemplate(
      id: id ?? this.id,
      content: content ?? this.content,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// שם קטגוריה בעברית
  String get categoryName {
    switch (category) {
      case MessageCategory.regular:
        return 'היום ביילה';
      case MessageCategory.pace:
        return 'שיעור קצב';
      case MessageCategory.afro:
        return 'שיעור אפרו';
      case MessageCategory.pachanga:
        return 'שיעור פצ\'אנגה';
      case MessageCategory.laPrep:
        return 'הכנה ל-LA';
      case MessageCategory.shines:
        return 'הפלות';
    }
  }
}

/// מודל אירוע שליחת הודעה
class MessageEvent {
  final String id;
  final DateTime scheduledDate;
  final MessageCategory category;
  final String? lockedBy;
  final String? lockedByName;
  final DateTime? lockedAt;
  final String? finalMessage;
  final bool isSent;
  final DateTime? sentAt;
  final String? sentBy;
  final String? sentByName;

  MessageEvent({
    required this.id,
    required this.scheduledDate,
    required this.category,
    this.lockedBy,
    this.lockedByName,
    this.lockedAt,
    this.finalMessage,
    this.isSent = false,
    this.sentAt,
    this.sentBy,
    this.sentByName,
  });

  /// המרה מ-Firestore
  factory MessageEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageEvent(
      id: doc.id,
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      category: MessageCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => MessageCategory.regular,
      ),
      lockedBy: data['lockedBy'],
      lockedByName: data['lockedByName'],
      lockedAt: (data['lockedAt'] as Timestamp?)?.toDate(),
      finalMessage: data['finalMessage'],
      isSent: data['isSent'] ?? false,
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      sentBy: data['sentBy'],
      sentByName: data['sentByName'],
    );
  }

  /// המרה ל-Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'category': category.name,
      'lockedBy': lockedBy,
      'lockedByName': lockedByName,
      'lockedAt': lockedAt != null ? Timestamp.fromDate(lockedAt!) : null,
      'finalMessage': finalMessage,
      'isSent': isSent,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'sentBy': sentBy,
      'sentByName': sentByName,
    };
  }

  /// בדיקה האם ההודעה נעולה
  bool get isLocked => lockedBy != null && !isSent;

  /// בדיקה האם המשתמש הנוכחי נעל את ההודעה
  bool isLockedByUser(String userId) => lockedBy == userId;

  /// העתקה עם שינויים
  MessageEvent copyWith({
    String? id,
    DateTime? scheduledDate,
    MessageCategory? category,
    String? lockedBy,
    String? lockedByName,
    DateTime? lockedAt,
    String? finalMessage,
    bool? isSent,
    DateTime? sentAt,
    String? sentBy,
    String? sentByName,
  }) {
    return MessageEvent(
      id: id ?? this.id,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      category: category ?? this.category,
      lockedBy: lockedBy ?? this.lockedBy,
      lockedByName: lockedByName ?? this.lockedByName,
      lockedAt: lockedAt ?? this.lockedAt,
      finalMessage: finalMessage ?? this.finalMessage,
      isSent: isSent ?? this.isSent,
      sentAt: sentAt ?? this.sentAt,
      sentBy: sentBy ?? this.sentBy,
      sentByName: sentByName ?? this.sentByName,
    );
  }
}
