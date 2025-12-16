import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:personal_spendings/providers/secure_values_lock_service.dart';
import 'package:personal_spendings/screens/app_lock_gate.dart';
import 'package:personal_spendings/screens/auth_gate.dart';
import 'package:personal_spendings/services/app_lock_service.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart'; // keep this
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'providers/spending_provider.dart';
import 'providers/other_spending_provider.dart';

import 'theme.dart'; // 👈 your custom lightTheme / darkTheme

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SpendingProvider()),
        ChangeNotifierProvider(create: (_) => OtherSpendingProvider()),
        ChangeNotifierProvider(create: (_) => AppLockService()),
        ChangeNotifierProvider(create: (_) => SecureValuesLockService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spending Tracker',
      debugShowCheckedModeBanner: false,
      // 👇 back to your original design
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const AppLockGate(child: AuthGate()),
    );
  }
}
