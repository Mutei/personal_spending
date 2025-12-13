import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  AuthService() {
    _auth.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  /// signup with email + username
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    // 1) check username availability
    final taken = await FirestoreService.instance.usernameExists(
      username.trim(),
    );
    if (taken) {
      throw Exception('Username already taken, pick another one.');
    }

    // 2) create auth user
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 3) create firestore user doc
    if (cred.user != null) {
      await FirestoreService.instance.createUserDoc(
        uid: cred.user!.uid,
        email: email,
        username: username.trim(),
      );
    }
  }

  /// login with email OR username
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    String? email;

    if (identifier.contains('@')) {
      // treat as email
      email = identifier.trim();
    } else {
      // treat as username
      email = await FirestoreService.instance.getEmailFromUsername(
        identifier.trim(),
      );
      if (email == null) {
        throw Exception('No user found with that username.');
      }
    }

    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
