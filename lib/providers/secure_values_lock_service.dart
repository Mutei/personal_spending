import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class SecureValuesLockService extends ChangeNotifier {
  final LocalAuthentication _auth = LocalAuthentication();

  bool _unlocked = false; // default locked on app start
  bool get isUnlocked => _unlocked;
  bool get isLocked => !_unlocked;

  /// Call this on app start / resume to force lock.
  void lock() {
    if (_unlocked) {
      _unlocked = false;
      notifyListeners();
    }
  }

  /// Unlock requires biometrics (or device auth if you want).
  Future<bool> unlockWithBiometrics() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canBio = await _auth.canCheckBiometrics;

      if (!isSupported || !canBio) return false;

      final ok = await _auth.authenticate(
        localizedReason: 'Unlock sensitive amounts',
        biometricOnly: true,
      );

      if (ok) {
        _unlocked = true;
        notifyListeners();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Convenience toggle: locked -> unlock (bio), unlocked -> lock (no bio).
  Future<bool> toggle() async {
    if (_unlocked) {
      lock();
      return true;
    }
    return unlockWithBiometrics();
  }
}
