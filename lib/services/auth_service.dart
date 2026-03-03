import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';
import 'notification_token_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  AuthService() {
    // Initialize immediately
    _currentUser = _auth.currentUser;

    // ✅ VERY IMPORTANT:
    // If user already logged in (existing account, after app update),
    // register token when app starts.
    final uid = _currentUser?.uid;
    if (uid != null) {
      // don't block UI startup
      NotificationTokenService.instance
          .registerTokenForUser(uid)
          .catchError((_) {});
    }

    // Listen to Firebase auth changes and notify UI
    _auth.authStateChanges().listen((user) async {
      _currentUser = user;

      // ✅ When user becomes logged in, ensure token is saved
      if (user != null) {
        try {
          await NotificationTokenService.instance.registerTokenForUser(
            user.uid,
          );
        } catch (_) {
          // avoid crashing auth stream
        }
      }

      notifyListeners();
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final taken = await FirestoreService.instance.usernameExists(
      username.trim(),
    );
    if (taken) {
      throw Exception('Username already taken, pick another one.');
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = cred.user;
    if (user != null) {
      await FirestoreService.instance.createUserDoc(
        uid: user.uid,
        email: email.trim(),
        username: username.trim(),
      );

      // ✅ Save token for this device
      await NotificationTokenService.instance.registerTokenForUser(user.uid);
    }

    _currentUser = _auth.currentUser;
    notifyListeners();
  }

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    String? email;
    final id = identifier.trim();

    if (id.contains('@')) {
      email = id;
    } else {
      email = await FirestoreService.instance.getEmailFromUsername(id);
      if (email == null) {
        throw Exception('No user found with that username.');
      }
    }

    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // ✅ Save token for this device
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await NotificationTokenService.instance.registerTokenForUser(uid);
    }

    _currentUser = _auth.currentUser;
    notifyListeners();
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;

    // ✅ Remove THIS device token from the user token list
    if (uid != null) {
      try {
        await NotificationTokenService.instance.unregisterTokenForUser(uid);
      } catch (_) {}
    }

    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
