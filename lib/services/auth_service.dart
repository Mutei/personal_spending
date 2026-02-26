import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Keep a cached user so UI can react instantly (and consistently)
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  AuthService() {
    // Initialize immediately
    _currentUser = _auth.currentUser;

    // Listen to Firebase auth changes and notify UI
    _auth.authStateChanges().listen((user) {
      _currentUser = user;
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
      email: email.trim(),
      password: password,
    );

    // 3) create firestore user doc
    if (cred.user != null) {
      await FirestoreService.instance.createUserDoc(
        uid: cred.user!.uid,
        email: email.trim(),
        username: username.trim(),
      );
    }

    // Make sure local state is up to date (authStateChanges will also fire)
    _currentUser = _auth.currentUser;
    notifyListeners();
  }

  /// login with email OR username
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    String? email;

    final id = identifier.trim();

    if (id.contains('@')) {
      // treat as email
      email = id;
    } else {
      // treat as username
      email = await FirestoreService.instance.getEmailFromUsername(id);
      if (email == null) {
        throw Exception('No user found with that username.');
      }
    }

    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Update local cache immediately (authStateChanges will also fire)
    _currentUser = _auth.currentUser;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();

    // Update local cache immediately (authStateChanges will also fire)
    _currentUser = null;
    notifyListeners();
  }
}
