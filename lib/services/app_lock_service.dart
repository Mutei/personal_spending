import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService extends ChangeNotifier {
  static const _keyEnabled = 'app_lock_enabled';

  final LocalAuthentication _auth = LocalAuthentication();
  bool _enabled = false;
  bool _unlockedThisSession = false;

  bool get isEnabled => _enabled;
  bool get isUnlocked => !_enabled || _unlockedThisSession;

  AppLockService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? false;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = value;
    _unlockedThisSession = false;
    await prefs.setBool(_keyEnabled, value);
    notifyListeners();
  }

  Future<bool> authenticate() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canBio = await _auth.canCheckBiometrics;

      debugPrint("AppLock -> isDeviceSupported: $isSupported");
      debugPrint("AppLock -> canCheckBiometrics: $canBio");

      if (!isSupported) {
        debugPrint("AppLock -> Device not supported");
        return false;
      }

      // This will show PIN/pattern if biometrics not available (since biometricOnly=false)
      final success = await _auth.authenticate(
        localizedReason: 'Unlock Spending Tracker',
        biometricOnly: false,
        // stickyAuth: true,
        // useErrorDialogs: true,
      );

      debugPrint("AppLock -> authenticate result: $success");
      if (success) {
        _unlockedThisSession = true;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint("AppLock -> authenticate ERROR: $e");
      return false;
    }
  }

  void lockAgain() {
    _unlockedThisSession = false;
  }
}
