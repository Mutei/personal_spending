import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:personal_spendings/localization/demo_localization.dart';
import 'package:personal_spendings/localization/language_constants.dart';
import 'package:personal_spendings/providers/notification_center_provider.dart';
import 'package:personal_spendings/providers/secure_values_lock_service.dart';
import 'package:personal_spendings/screens/app_lock_gate.dart';
import 'package:personal_spendings/screens/auth_gate.dart';
import 'package:personal_spendings/services/app_lock_service.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/other_spending_provider.dart';
import 'providers/spending_provider.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';

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
        ChangeNotifierProvider(create: (_) => NotificationCenterProvider()),
        ChangeNotifierProvider(create: (_) => AppLockService()),
        ChangeNotifierProvider(create: (_) => SecureValuesLockService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en', 'US');

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final locale = await getLocale();
    if (!mounted) return;
    setState(() => _locale = locale);
  }

  void setLocale(Locale locale) {
    if (!mounted) return;
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spending Tracker',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      locale: _locale,
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'SA')],
      localizationsDelegates: const [
        DemoLocalization.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const AppLockGate(child: AuthGate()),
    );
  }
}
