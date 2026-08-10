import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../localization/language_constants.dart';

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

  static Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final granted = await androidImpl?.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  static Future<void> showOverSpendNotification({
    required double todayTotal,
    required double allowed,
  }) async {
    final title = await getTranslatedForCurrentLocale(
      'Daily spending exceeded',
    );
    final body = await getTranslatedForCurrentLocale(
      'You spent {todayTotal} but your limit is {allowed}',
    );
    await showNotification(
      notificationKey: 'overspend-alert',
      title: title,
      body: body
          .replaceAll('{todayTotal}', todayTotal.toStringAsFixed(2))
          .replaceAll('{allowed}', allowed.toStringAsFixed(2)),
    );
  }

  static Future<void> showNotification({
    required String notificationKey,
    required String title,
    required String body,
    String? payload,
  }) async {
    final granted = await requestPermission();

    if (!granted) {
      throw Exception(
        await getTranslatedForCurrentLocale(
          'Notification permission was not granted.',
        ),
      );
    }

    const androidDetails = AndroidNotificationDetails(
      'spending_channel',
      'Spending Alerts',
      channelDescription:
          'Notifications for spending summaries and budget alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notifications.show(
      _notificationIdFromKey(notificationKey),
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: payload,
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
      // androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
