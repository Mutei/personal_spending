import 'package:flutter/material.dart';
import 'package:personal_spendings/screens/root_screen.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../providers/spending_provider.dart';
import '../services/app_lock_service.dart';
import 'lock_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final lock = context.watch<AppLockService>();

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    if (!lock.isUnlocked) {
      return LockScreen();
    }

    final uid = auth.currentUser!.uid;

    return FutureBuilder(
      future: _initUserData(context, uid),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const RootScreen();
      },
    );
  }

  Future<void> _initUserData(BuildContext context, String uid) async {
    // 1) attach user (remote pull may happen here)
    await context.read<SpendingProvider>().attachUser(uid);

    // 2) load LOCAL data for this uid (user-scoped prefs)
    await context.read<SpendingProvider>().loadData(uid);

    // If OtherSpendingProvider also uses SharedPreferences, do the same:
    // await context.read<OtherSpendingProvider>().loadData(uid);
  }
}
