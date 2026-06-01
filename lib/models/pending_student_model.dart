import 'package:cloud_firestore/cloud_firestore.dart';

/// Student details submitted from the public join form and awaiting approval.
class PendingStudentModel {
  final String id;
  final String name;
  final String phoneNumber;
  final DateTime birthday;
  final DateTime submittedAt;
  final String status;

  const PendingStudentModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.birthday,
    required this.submittedAt,
    required this.status,
  });

  factory PendingStudentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PendingStudentModel(
      id: doc.id,
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      birthday: (data['birthday'] as Timestamp?)?.toDate() ?? DateTime.now(),
      submittedAt:
          (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }
}
