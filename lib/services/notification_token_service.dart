import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

class NotificationTokenService {
  NotificationTokenService._();
  static final instance = NotificationTokenService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _currentToken;
  String? _currentUid;
  bool _refreshListenerAttached = false;

  String get platformName {
    if (kIsWeb) return "web";
    if (Platform.isAndroid) return "android";
    if (Platform.isIOS) return "ios";
    return "unknown";
  }

  /// Call this after user is logged in and you have uid.
  Future<void> registerTokenForUser(String uid) async {
    _currentUid = uid;

    // 1) Request permission (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // User denied notifications -> don't store token
      return;
    }

    // 2) Get token
    final token = await _messaging.getToken();
    if (token == null) return;

    // Small optimization: if token didn't change and we already saved before,
    // we still "touch" it to keep lastSeen fresh.
    if (_currentToken == token) {
      await FirestoreService.instance.touchFcmToken(uid: uid, token: token);
    } else {
      _currentToken = token;

      // 3) Save token in Firestore (multi-device safe)
      await FirestoreService.instance.saveFcmToken(
        uid: uid,
        token: token,
        platform: platformName,
      );
    }

    // 4) Attach refresh listener ONCE (and always save to current uid)
    if (!_refreshListenerAttached) {
      _refreshListenerAttached = true;

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        _currentToken = newToken;
        final activeUid = _currentUid;
        if (activeUid == null) return;

        await FirestoreService.instance.saveFcmToken(
          uid: activeUid,
          token: newToken,
          platform: platformName,
        );
      });
    }
  }

  /// Optional but recommended: call on logout so this device stops receiving pushes for that account
  Future<void> unregisterTokenForUser(String uid) async {
    final token = _currentToken ?? await _messaging.getToken();
    if (token == null) return;

    await FirestoreService.instance.deleteFcmToken(uid: uid, token: token);

    // Clear local cache only if same uid
    if (_currentUid == uid) {
      _currentUid = null;
      _currentToken = null;
    }
  }
}
