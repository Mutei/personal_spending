import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/spending_notification.dart';
import '../services/notification_service.dart';
import 'other_spending_provider.dart';
import 'spending_provider.dart';

class NotificationCenterProvider extends ChangeNotifier {
  static const Duration _retention = Duration(days: 7);
  static const List<int> _reminderDaysBeforeExpiration = [3, 2, 1];

  String? _uid;
  final List<SpendingNotification> _notifications = <SpendingNotification>[];
  final Set<String> _deletedIds = <String>{};
  bool _isLoaded = false;
  bool _syncInProgress = false;

  List<SpendingNotification> get notifications {
    final copy = List<SpendingNotification>.from(_notifications);
    copy.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return copy;
  }

  int get unreadCount => _notifications.where((item) => !item.isRead).length;

  Future<void> attachUser(String? uid) async {
    if (_uid == uid && _isLoaded) return;

    _uid = uid;
    _notifications.clear();
    _deletedIds.clear();
    _isLoaded = false;

    if (uid == null) {
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final notificationsRaw = prefs.getString(_notificationsKey(uid));
    final deletedRaw = prefs.getString(_deletedKey(uid));

    if (notificationsRaw != null && notificationsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(notificationsRaw);
        if (decoded is List) {
          _notifications.addAll(
            decoded.whereType<Map>().map(
              (item) => SpendingNotification.fromJson(
                Map<String, dynamic>.from(item),
              ),
            ),
          );
        }
      } catch (_) {
        // Ignore malformed notification cache.
      }
    }

    if (deletedRaw != null && deletedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(deletedRaw);
        if (decoded is List) {
          _deletedIds.addAll(decoded.whereType<String>());
        }
      } catch (_) {
        // Ignore malformed tombstones.
      }
    }

    _purgeExpiredNotifications();
    _isLoaded = true;
    await _save();
    notifyListeners();
  }

  Future<void> syncFromData({
    required SpendingProvider spending,
    required OtherSpendingProvider other,
  }) async {
    if (_uid == null || !_isLoaded || _syncInProgress) return;
    _syncInProgress = true;

    try {
      var changed = false;
      changed = _purgeExpiredNotifications() || changed;

      final now = DateTime.now();
      final reportDates = _eligibleReportDates(
        now: now,
        spending: spending,
        other: other,
      );

      for (final date in reportDates) {
        changed =
            _upsertDailyReportNotification(
              spending: spending,
              other: other,
              date: date,
              now: now,
            ) ||
            changed;
      }

      changed = _removeOrphanReminderNotifications() || changed;

      final dailyNotifications = _notifications
          .where((item) => item.type == SpendingNotificationType.dailyReport)
          .toList();

      for (final notification in dailyNotifications) {
        changed = _ensureReminderNotifications(notification, now) || changed;
      }

      await _scheduleUpcomingNotifications(spending: spending, other: other);

      if (changed) {
        await _save();
        notifyListeners();
      }
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere(
      (item) => item.id == notificationId,
    );
    if (index == -1 || _notifications[index].isRead) return;

    _notifications[index] = _notifications[index].copyWith(isRead: true);
    await _save();
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    var changed = false;
    for (var i = 0; i < _notifications.length; i++) {
      if (_notifications[i].isRead) continue;
      _notifications[i] = _notifications[i].copyWith(isRead: true);
      changed = true;
    }
    if (!changed) return;
    await _save();
    notifyListeners();
  }

  Future<void> deleteNotification(String notificationId) async {
    final notification = _notifications
        .cast<SpendingNotification?>()
        .firstWhere((item) => item?.id == notificationId, orElse: () => null);
    if (notification == null) return;

    final idsToDelete = <String>{notification.id};
    if (notification.type == SpendingNotificationType.dailyReport) {
      idsToDelete.addAll(
        _notifications
            .where((item) => item.parentId == notification.id)
            .map((item) => item.id),
      );
    }

    _notifications.removeWhere((item) => idsToDelete.contains(item.id));
    _deletedIds.addAll(idsToDelete);

    for (final id in idsToDelete) {
      await NotificationService.cancelNotificationByKey(id);
    }

    await _save();
    notifyListeners();
  }

  bool _upsertDailyReportNotification({
    required SpendingProvider spending,
    required OtherSpendingProvider other,
    required DateTime date,
    required DateTime now,
  }) {
    final id = _dailyReportId(date);
    if (_deletedIds.contains(id)) return false;

    final dateOnly = DateTime(date.year, date.month, date.day);
    final timestamp = DateTime(dateOnly.year, dateOnly.month, dateOnly.day, 23);
    final expiresAt = timestamp.add(_retention);
    if (expiresAt.isBefore(now)) return false;

    final message = _dailyReportMessage(dateOnly, spending, other);
    final existingIndex = _notifications.indexWhere((item) => item.id == id);

    if (existingIndex == -1) {
      _notifications.add(
        SpendingNotification(
          id: id,
          type: SpendingNotificationType.dailyReport,
          title: 'Daily spending summary',
          message: message,
          timestamp: timestamp,
          expiresAt: expiresAt,
          reportDate: dateOnly,
        ),
      );
      return true;
    }

    final current = _notifications[existingIndex];
    if (current.message == message &&
        current.expiresAt == expiresAt &&
        current.timestamp == timestamp) {
      return false;
    }

    _notifications[existingIndex] = current.copyWith(
      message: message,
      timestamp: timestamp,
      expiresAt: expiresAt,
      reportDate: dateOnly,
    );
    return true;
  }

  bool _ensureReminderNotifications(
    SpendingNotification dailyNotification,
    DateTime now,
  ) {
    var changed = false;

    for (final daysBefore in _reminderDaysBeforeExpiration) {
      final reminderId = _reminderId(dailyNotification.id, daysBefore);
      if (_deletedIds.contains(reminderId)) continue;

      final reminderTime = dailyNotification.expiresAt.subtract(
        Duration(days: daysBefore),
      );
      if (now.isBefore(reminderTime) ||
          !now.isBefore(dailyNotification.expiresAt)) {
        continue;
      }

      final existingIndex = _notifications.indexWhere(
        (item) => item.id == reminderId,
      );
      final title =
          'Report expires in $daysBefore day${daysBefore == 1 ? '' : 's'}';
      final message =
          'Your daily spending report for ${DateFormat('yyyy-MM-dd').format(dailyNotification.reportDate!)} will expire in $daysBefore day${daysBefore == 1 ? '' : 's'}. Download the PDF if you want to keep it.';

      if (existingIndex == -1) {
        _notifications.add(
          SpendingNotification(
            id: reminderId,
            type: SpendingNotificationType.reminder,
            title: title,
            message: message,
            timestamp: reminderTime,
            expiresAt: dailyNotification.expiresAt,
            reportDate: dailyNotification.reportDate,
            parentId: dailyNotification.id,
          ),
        );
        changed = true;
        continue;
      }

      final current = _notifications[existingIndex];
      if (current.message == message && current.timestamp == reminderTime) {
        continue;
      }
      _notifications[existingIndex] = current.copyWith(
        title: title,
        message: message,
        timestamp: reminderTime,
        expiresAt: dailyNotification.expiresAt,
        reportDate: dailyNotification.reportDate,
        parentId: dailyNotification.id,
      );
      changed = true;
    }

    return changed;
  }

  bool _removeOrphanReminderNotifications() {
    final validParentIds = _notifications
        .where((item) => item.type == SpendingNotificationType.dailyReport)
        .map((item) => item.id)
        .toSet();
    final before = _notifications.length;
    _notifications.removeWhere(
      (item) =>
          item.parentId != null && !validParentIds.contains(item.parentId),
    );
    return before != _notifications.length;
  }

  bool _purgeExpiredNotifications() {
    final now = DateTime.now();
    final expiredIds = _notifications
        .where((item) => !item.expiresAt.isAfter(now))
        .map((item) => item.id)
        .toList();
    if (expiredIds.isEmpty) return false;

    _notifications.removeWhere((item) => expiredIds.contains(item.id));
    _deletedIds.removeWhere((id) => expiredIds.contains(id));
    for (final id in expiredIds) {
      NotificationService.cancelNotificationByKey(id);
    }
    return true;
  }

  Iterable<DateTime> _eligibleReportDates({
    required DateTime now,
    required SpendingProvider spending,
    required OtherSpendingProvider other,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final dates = <DateTime>{};

    for (var i = 0; i < _retention.inDays; i++) {
      dates.add(today.subtract(Duration(days: i)));
    }

    dates.addAll(
      spending.getRecordedSpendingDates(
        start: now.subtract(_retention),
        end: now,
      ),
    );
    if (spending.notificationPreferences.includeOtherSpending) {
      dates.addAll(
        other.getRecordedDates().where(
          (date) => !date.isBefore(today.subtract(_retention)),
        ),
      );
    }

    return dates.where((date) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final timestamp = DateTime(
        dateOnly.year,
        dateOnly.month,
        dateOnly.day,
        23,
      );
      return !timestamp.isAfter(now);
    });
  }

  Future<void> _scheduleUpcomingNotifications({
    required SpendingProvider spending,
    required OtherSpendingProvider other,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduledAt = DateTime(today.year, today.month, today.day, 23);
    final todayId = _dailyReportId(today);

    if (spending.notificationPreferences.dailySummaryEnabled &&
        !_deletedIds.contains(todayId) &&
        scheduledAt.isAfter(now)) {
      await NotificationService.scheduleNotification(
        notificationKey: todayId,
        title: 'Daily spending summary',
        body: _dailyReportMessage(today, spending, other),
        scheduledAt: scheduledAt,
        payload: todayId,
      );
    } else {
      await NotificationService.cancelNotificationByKey(todayId);
    }

    for (final dailyNotification in _notifications.where(
      (item) => item.type == SpendingNotificationType.dailyReport,
    )) {
      for (final daysBefore in _reminderDaysBeforeExpiration) {
        final reminderId = _reminderId(dailyNotification.id, daysBefore);
        final reminderTime = dailyNotification.expiresAt.subtract(
          Duration(days: daysBefore),
        );
        if (_deletedIds.contains(reminderId) ||
            _deletedIds.contains(dailyNotification.id)) {
          await NotificationService.cancelNotificationByKey(reminderId);
          continue;
        }
        if (!reminderTime.isAfter(now)) continue;

        await NotificationService.scheduleNotification(
          notificationKey: reminderId,
          title:
              'Report expires in $daysBefore day${daysBefore == 1 ? '' : 's'}',
          body:
              'Your daily spending report for ${DateFormat('yyyy-MM-dd').format(dailyNotification.reportDate!)} will expire in $daysBefore day${daysBefore == 1 ? '' : 's'}. Download the PDF if you want to keep it.',
          scheduledAt: reminderTime,
          payload: reminderId,
        );
      }
    }

    for (final notification in _notifications.where(
      (item) => item.parentId != null,
    )) {
      if (_deletedIds.contains(notification.id)) {
        await NotificationService.cancelNotificationByKey(notification.id);
        continue;
      }
      if (notification.timestamp.isAfter(now)) {
        await NotificationService.scheduleNotification(
          notificationKey: notification.id,
          title: notification.title,
          body: notification.message,
          scheduledAt: notification.timestamp,
          payload: notification.id,
        );
      } else {
        await NotificationService.cancelNotificationByKey(notification.id);
      }
    }
  }

  String _dailyReportMessage(
    DateTime date,
    SpendingProvider spending,
    OtherSpendingProvider other,
  ) {
    final personalEntries = spending.getEntriesForDate(date);
    final otherEntries = spending.notificationPreferences.includeOtherSpending
        ? other.getUniqueEntriesForDate(date)
        : const [];

    final transactionCount = personalEntries.length + otherEntries.length;
    final totalSpent =
        personalEntries.fold<double>(0, (sum, entry) => sum + entry.amount) +
        otherEntries.fold<double>(0, (sum, entry) => sum + entry.amount);

    return '${DateFormat('EEE, MMM d').format(date)} • $transactionCount transactions • ${_formatAmount(totalSpent)}';
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notificationsKey(uid),
      jsonEncode(_notifications.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(_deletedKey(uid), jsonEncode(_deletedIds.toList()));
  }

  String _notificationsKey(String uid) => 'u:$uid:notificationCenterItems';
  String _deletedKey(String uid) => 'u:$uid:notificationCenterDeletedIds';

  String _dailyReportId(DateTime date) =>
      'daily-report-${DateFormat('yyyy-MM-dd').format(date)}';

  String _reminderId(String parentId, int daysBefore) =>
      '$parentId-reminder-$daysBefore';

  String _formatAmount(double amount) =>
      '${NumberFormat('#,##0.00').format(amount)} SAR';
}
