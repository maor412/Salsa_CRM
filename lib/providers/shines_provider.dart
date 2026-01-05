import 'package:flutter/foundation.dart';
import '../models/shines_item_model.dart';
import '../services/shines_service.dart';

/// Provider לניהול מצב תרגילי השיינס
class ShinesProvider with ChangeNotifier {
  final ShinesService _shinesService = ShinesService();

  List<ShinesItemModel> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ShinesItemModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// האזנה לשינויים ב-Firestore
  void listenToShines() {
    _shinesService.getShinesItems().listen(
      (items) {
        _items = items;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'שגיאה בטעינת שיינסים: $error';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// הוספת תרגיל שיינס חדש
  Future<bool> addShinesItem(String text) async {
    if (text.trim().isEmpty) {
      _errorMessage = 'נא להזין טקסט';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _shinesService.addShinesItem(text.trim());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'שגיאה בהוספת שיינס: $e';
      notifyListeners();
      return false;
    }
  }

  /// עדכון תרגיל שיינס קיים
  Future<bool> updateShinesItem(String id, String newText) async {
    if (newText.trim().isEmpty) {
      _errorMessage = 'נא להזין טקסט';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _shinesService.updateShinesItem(id, newText.trim());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'שגיאה בעדכון שיינס: $e';
      notifyListeners();
      return false;
    }
  }

  /// מחיקת תרגיל שיינס
  Future<bool> deleteShinesItem(String id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _shinesService.deleteShinesItem(id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'שגיאה במחיקת שיינס: $e';
      notifyListeners();
      return false;
    }
  }

  /// ניקוי הודעת שגיאה
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
