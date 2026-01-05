import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shines_item_model.dart';
import '../config/firebase_config.dart';

/// שירות לניהול תרגילי שיינס ב-Firestore
class ShinesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// קבלת כל תרגילי השיינס (stream)
  Stream<List<ShinesItemModel>> getShinesItems() {
    return _firestore
        .collection(FirebaseConfig.shinesCollection)
        .orderBy('orderIndex', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ShinesItemModel.fromFirestore(doc))
            .toList());
  }

  /// הוספת תרגיל שיינס חדש
  Future<String> addShinesItem(String text) async {
    try {
      // קבלת ה-orderIndex הבא
      final snapshot = await _firestore
          .collection(FirebaseConfig.shinesCollection)
          .orderBy('orderIndex', descending: true)
          .limit(1)
          .get();

      int nextOrder = 0;
      if (snapshot.docs.isNotEmpty) {
        final lastItem = ShinesItemModel.fromFirestore(snapshot.docs.first);
        nextOrder = lastItem.orderIndex + 1;
      }

      // יצירת הפריט החדש
      final newItem = ShinesItemModel(
        id: '',
        text: text,
        orderIndex: nextOrder,
        createdAt: DateTime.now(),
      );

      // שמירה ב-Firestore
      final docRef = await _firestore
          .collection(FirebaseConfig.shinesCollection)
          .add(newItem.toFirestore());

      return docRef.id;
    } catch (e) {
      print('Error adding shines item: $e');
      rethrow;
    }
  }

  /// עדכון תרגיל שיינס קיים
  Future<void> updateShinesItem(String id, String newText) async {
    try {
      await _firestore
          .collection(FirebaseConfig.shinesCollection)
          .doc(id)
          .update({'text': newText});
    } catch (e) {
      print('Error updating shines item: $e');
      rethrow;
    }
  }

  /// מחיקת תרגיל שיינס
  Future<void> deleteShinesItem(String id) async {
    try {
      await _firestore
          .collection(FirebaseConfig.shinesCollection)
          .doc(id)
          .delete();
    } catch (e) {
      print('Error deleting shines item: $e');
      rethrow;
    }
  }

  /// עדכון סדר התרגילים
  Future<void> reorderShinesItems(List<ShinesItemModel> items) async {
    try {
      final batch = _firestore.batch();

      for (int i = 0; i < items.length; i++) {
        final docRef = _firestore
            .collection(FirebaseConfig.shinesCollection)
            .doc(items[i].id);
        batch.update(docRef, {'orderIndex': i});
      }

      await batch.commit();
    } catch (e) {
      print('Error reordering shines items: $e');
      rethrow;
    }
  }
}
