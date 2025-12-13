import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _notifications.initialize(settings);

    // ask permission on Android 13+
    await requestPermission();
  }

  static Future<void> requestPermission() async {
    if (Platform.isAndroid) {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.requestNotificationsPermission();
    }
  }

  static Future<void> showOverSpendNotification({
    required double todayTotal,
    required double allowed,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'spending_channel',
      'Spending Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.show(
      1,
      'Daily spending exceeded',
      'You spent ${todayTotal.toStringAsFixed(2)} but your limit is ${allowed.toStringAsFixed(2)}',
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> showDailySummaryNotification({
    required double periodTotal,
    required double? budget,
    required double todayTotal,
  }) async {
    final percent = (budget != null && budget > 0)
        ? ((periodTotal / budget) * 100).clamp(0, 999).toStringAsFixed(0)
        : null;

    final subtitle = percent != null
        ? 'Period total: ${periodTotal.toStringAsFixed(2)} (${percent}%)'
        : 'Period total: ${periodTotal.toStringAsFixed(2)}';

    const androidDetails = AndroidNotificationDetails(
      'spending_channel',
      'Spending Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.show(
      2,
      'Daily summary',
      'Today: ${todayTotal.toStringAsFixed(2)} | $subtitle',
      const NotificationDetails(android: androidDetails),
    );
  }
}
