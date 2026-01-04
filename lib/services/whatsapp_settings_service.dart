import 'package:cloud_firestore/cloud_firestore.dart';

/// שירות לניהול הגדרות WhatsApp מ-Firestore
class WhatsAppSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for group link to avoid repeated Firestore reads
  String? _cachedGroupLink;
  DateTime? _cacheTime;
  final Duration _cacheDuration = const Duration(hours: 1);

  /// קריאת קישור קבוצת WhatsApp מ-Firestore
  ///
  /// Returns: קישור הקבוצה או null אם לא קיים
  Future<String?> getGroupLink() async {
    try {
      // Check cache first
      if (_cachedGroupLink != null &&
          _cacheTime != null &&
          DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _cachedGroupLink;
      }

      // Read from Firestore
      final doc = await _firestore
          .collection('settings')
          .doc('whatsapp')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _cachedGroupLink = data['groupLink'] as String?;
        _cacheTime = DateTime.now();
        return _cachedGroupLink;
      }

      return null;
    } catch (e) {
      print('Error reading WhatsApp group link: $e');
      return null;
    }
  }

  /// עדכון קישור קבוצת WhatsApp ב-Firestore (Admin only)
  ///
  /// [groupLink] - הקישור החדש לקבוצה
  Future<void> updateGroupLink(String groupLink) async {
    try {
      await _firestore
          .collection('settings')
          .doc('whatsapp')
          .set({
        'groupLink': groupLink,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update cache
      _cachedGroupLink = groupLink;
      _cacheTime = DateTime.now();
    } catch (e) {
      print('Error updating WhatsApp group link: $e');
      rethrow;
    }
  }

  /// ניקוי Cache (שימושי לאחר עדכון)
  void clearCache() {
    _cachedGroupLink = null;
    _cacheTime = null;
  }

  /// בדיקה אם קישור הקבוצה תקין
  ///
  /// Returns: true אם הקישור בפורמט נכון של WhatsApp group
  static bool isValidGroupLink(String link) {
    if (link.isEmpty) return false;

    // WhatsApp group invite links format:
    // https://chat.whatsapp.com/XXXXXXXXXXXXX
    final groupLinkRegex = RegExp(
      r'^https?:\/\/chat\.whatsapp\.com\/[A-Za-z0-9]+$',
      caseSensitive: false,
    );

    return groupLinkRegex.hasMatch(link.trim());
  }
}
