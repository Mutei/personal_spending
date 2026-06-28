import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _timezoneInitialized = false;

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _notifications.initialize(settings);
    _initializeTimezones();

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

  static Future<void> scheduleNotification({
    required String notificationKey,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {
    _initializeTimezones();
    final now = DateTime.now();
    if (!scheduledAt.isAfter(now)) return;

    const androidDetails = AndroidNotificationDetails(
      'spending_channel',
      'Spending Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    final scheduledDate = tz.TZDateTime.from(scheduledAt, tz.local);
    await _notifications.zonedSchedule(
      _notificationIdFromKey(notificationKey),
      title,
      body,
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      matchDateTimeComponents: null,
    );
  }

  static Future<void> cancelNotificationByKey(String notificationKey) async {
    await _notifications.cancel(_notificationIdFromKey(notificationKey));
  }

  static Future<void> showDailySummaryNotification({
    required double periodTotal,
    required double? budget,
    required double todayTotal,
    double? bankBalanceTotal,
    bool includeBudgetContext = true,
    bool includeBankContext = true,
  }) async {
    final percent = (includeBudgetContext && budget != null && budget > 0)
        ? ((periodTotal / budget) * 100).clamp(0, 999).toStringAsFixed(0)
        : null;

    final parts = <String>['Today: ${todayTotal.toStringAsFixed(2)}'];

    if (includeBudgetContext) {
      final subtitle = percent != null
          ? 'Period: ${periodTotal.toStringAsFixed(2)} ($percent%)'
          : 'Period: ${periodTotal.toStringAsFixed(2)}';
      parts.add(subtitle);
    }

    if (includeBankContext && bankBalanceTotal != null) {
      parts.add('Bank total: ${bankBalanceTotal.toStringAsFixed(2)}');
    }

    const androidDetails = AndroidNotificationDetails(
      'spending_channel',
      'Spending Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.show(
      2,
      'Daily summary',
      parts.join(' | '),
      const NotificationDetails(android: androidDetails),
    );
  }

  static void _initializeTimezones() {
    if (_timezoneInitialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
    _timezoneInitialized = true;
  }

  static int _notificationIdFromKey(String key) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = 0x1fffffff & (hash + unit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= (hash >> 11);
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash & 0x7fffffff;
  }
}
