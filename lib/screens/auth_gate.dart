import 'package:flutter/material.dart';
import 'package:personal_spendings/screens/root_screen.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../services/app_lock_service.dart';
import 'lock_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final lock = context.watch<AppLockService>(); // 👈 NEW

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    if (!lock.isUnlocked) {
      return LockScreen();
    }

    return const RootScreen();
  }
}
