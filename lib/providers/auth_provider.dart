import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Provider לניהול אימות ומשתמש נוכחי
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitializing = true; // מצב אתחול ראשוני
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing; // גישה למצב אתחול
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  AuthProvider() {
    _init();
  }

  /// אתחול - האזנה לשינויים במצב ההתחברות
  void _init() {
    // בדיקת מצב אתחול ראשוני
    checkAuthStatus();

    // האזנה לשינויים עתידיים
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        _currentUser = await _authService.getUserData(user.uid);
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  /// בדיקת מצב אימות בהפעלה ראשונית
  Future<void> checkAuthStatus() async {
    try {
      _isInitializing = true;
      notifyListeners();

      // קבלת משתמש נוכחי מ-Firebase
      final currentFirebaseUser = _authService.currentUser;

      if (currentFirebaseUser != null) {
        // טעינת נתוני המשתמש מ-Firestore
        _currentUser = await _authService.getUserData(currentFirebaseUser.uid);
      } else {
        _currentUser = null;
      }
    } catch (e) {
      print('Error checking auth status: $e');
      _currentUser = null;
    } finally {
      // סיום אתחול
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// התחברות
  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      print('AuthProvider: Starting sign-in for $email');
      _currentUser = await _authService.signIn(email, password);
      print('AuthProvider: Sign-in completed, user: ${_currentUser?.email}');

      _isLoading = false;
      notifyListeners();

      if (_currentUser == null) {
        print('AuthProvider: Warning - currentUser is null after sign-in');
      }

      return _currentUser != null;
    } catch (e) {
      print('AuthProvider: Sign-in error: $e');
      _isLoading = false;
      _errorMessage = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// יציאה
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// יצירת משתמש (Admin בלבד)
  Future<bool> createUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    if (!isAdmin) {
      _errorMessage = 'אין לך הרשאה ליצור משתמשים';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _authService.createUser(
        email: email,
        password: password,
        name: name,
        role: role,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// ניקוי שגיאות
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// המרת שגיאות לעברית
  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'משתמש לא נמצא';
        case 'wrong-password':
          return 'סיסמה שגויה';
        case 'invalid-email':
          return 'שם משתמש לא תקין';
        case 'invalid-credential':
          return 'שם משתמש או סיסמה שגויים';
        case 'user-disabled':
          return 'המשתמש הושבת';
        case 'email-already-in-use':
          return 'שם המשתמש כבר בשימוש';
        case 'weak-password':
          return 'הסיסמה חלשה מדי';
        case 'network-request-failed':
          return 'אין חיבור לאינטרנט. אנא בדוק את החיבור שלך ונסה שוב';
        case 'too-many-requests':
          return 'יותר מדי ניסיונות. נסה שוב מאוחר יותר';
        default:
          return 'שגיאה בהתחברות: ${error.message}';
      }
    }
    return 'שגיאה: $error';
  }
}
