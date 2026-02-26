import 'package:local_auth/local_auth.dart';

class BiometricGate {
  final _auth = LocalAuthentication();

  Future<bool> unlock({String reason = "Confirm to switch account"}) async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported)
        return true; // fallback to allow if not supported
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }
}
