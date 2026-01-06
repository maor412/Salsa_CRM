import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../config/firebase_config.dart';

/// שירות אימות וניהול משתמשים
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream של משתמש מחובר
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// משתמש נוכחי
  User? get currentUser => _auth.currentUser;

  /// התחברות עם אימייל וסיסמה
  Future<UserModel?> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        return await getUserData(userCredential.user!.uid);
      }
      return null;
    } catch (e) {
      final fallbackUser = _auth.currentUser;
      if (fallbackUser != null && e.toString().contains('PigeonUserDetails')) {
        print('Sign-in result decode failed, using currentUser fallback: $e');
        return await getUserData(fallbackUser.uid);
      }
      print('Error signing in: $e');
      rethrow;
    }
  }

  /// יציאה מהמערכת
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// קבלת פרטי משתמש מ-Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      print('AuthService: Getting user data for UID: $uid');
      final doc = await _firestore
          .collection(FirebaseConfig.usersCollection)
          .doc(uid)
          .get();

      print('AuthService: Document exists: ${doc.exists}');
      if (doc.exists) {
        print('AuthService: Document data: ${doc.data()}');
        final user = UserModel.fromFirestore(doc);
        print('AuthService: User model created: ${user.email}');
        return user;
      }
      print('AuthService: User document not found in Firestore!');
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// יצירת משתמש חדש (Admin בלבד)
  Future<UserModel?> createUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      // יצירת משתמש ב-Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final user = UserModel(
          id: userCredential.user!.uid,
          email: email,
          name: name,
          role: role,
          createdAt: DateTime.now(),
          isActive: true,
        );

        // שמירת פרטי משתמש ב-Firestore
        await _firestore
            .collection(FirebaseConfig.usersCollection)
            .doc(user.id)
            .set(user.toFirestore());

        return user;
      }
      return null;
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  /// עדכון סטטוס משתמש (השבתה/הפעלה)
  Future<void> updateUserStatus(String uid, bool isActive) async {
    try {
      await _firestore
          .collection(FirebaseConfig.usersCollection)
          .doc(uid)
          .update({'isActive': isActive});
    } catch (e) {
      print('Error updating user status: $e');
      rethrow;
    }
  }

  /// קבלת כל המשתמשים (Admin בלבד)
  Stream<List<UserModel>> getAllUsers() {
    return _firestore
        .collection(FirebaseConfig.usersCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }
}
