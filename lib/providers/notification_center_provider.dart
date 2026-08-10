import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/demo_localization.dart';
import '../localization/language_constants.dart';
import '../models/spending_notification.dart';
import '../services/notification_service.dart';
import 'other_spending_provider.dart';
import 'spending_provider.dart';

class NotificationCenterProvider extends ChangeNotifier {
  static const Duration _retention = Duration(days: 7);
  static const List<int> _reminderDaysBeforeExpiration = [3, 2, 1];
  static const int _dailyNotificationHour = 23;

  String? _uid;
  final List<SpendingNotification> _notifications = <SpendingNotification>[];
  final Set<String> _deletedIds = <String>{};
  bool _isLoaded = false;
  bool _syncInProgress = false;
  String _languageCode = english;

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

    _languageCode = await getCurrentLanguageCode();

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
      _languageCode = await getCurrentLanguageCode();
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

      for (final date in _eligibleBudgetDates(now: now, spending: spending)) {
        changed =
            await _upsertBudgetAdjustmentNotification(
              spending: spending,
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

  Future<List<String>> sendTestSpendingNotifications({
    required SpendingProvider spending,
    required OtherSpendingProvider other,
  }) async {
    await NotificationService.requestPermission();
    _languageCode = await getCurrentLanguageCode();

    if (_uid != null && _isLoaded) {
      await syncFromData(spending: spending, other: other);
    }

    final now = DateTime.now();
    final sent = <String>[];

    final latestStoredDailyReport = _latestStoredNotification(
      (item) => item.type == SpendingNotificationType.dailyReport,
    );
    final reportDate =
        latestStoredDailyReport?.reportDate ??
        _latestEligibleReportDate(now: now, spending: spending, other: other);
    if (spending.notificationPreferences.dailySummaryEnabled &&
        reportDate != null) {
      final notificationId =
          latestStoredDailyReport?.id ?? _dailyReportId(reportDate);
      final title =
          latestStoredDailyReport?.title ?? _tr('Daily spending summary');
      final body =
          latestStoredDailyReport?.message ??
          _dailyReportMessage(reportDate, spending, other);
      await NotificationService.showNotification(
        notificationKey: '$notificationId-manual-${now.millisecondsSinceEpoch}',
        title: title,
        body: body,
        payload: notificationId,
      );
      sent.add(_tr('Daily summary'));
    }

    final latestStoredBudget = _latestStoredNotification(
      (item) =>
          item.type == SpendingNotificationType.budgetWarning ||
          item.type == SpendingNotificationType.budgetExceeded,
    );
    final budgetDate =
        latestStoredBudget?.reportDate ??
        _latestEligibleBudgetDate(now: now, spending: spending);
    if (latestStoredBudget != null) {
      await NotificationService.showNotification(
        notificationKey:
            '${latestStoredBudget.id}-manual-${now.millisecondsSinceEpoch}',
        title: latestStoredBudget.title,
        body: latestStoredBudget.message,
        payload: latestStoredBudget.id,
      );
      sent.add(_tr('Set budget'));
    } else if (budgetDate != null) {
      final adjustment = spending.getDailyBudgetAdjustmentForDate(budgetDate);
      if (adjustment != null) {
        final title = _dailyBudgetTitle(adjustment);
        final notificationId = _dailyBudgetId(budgetDate);
        await NotificationService.showNotification(
          notificationKey:
              '$notificationId-manual-${now.millisecondsSinceEpoch}',
          title: title,
          body: _dailyBudgetMessage(adjustment),
          payload: notificationId,
        );
        sent.add(_tr('Set budget'));
      }
    }

    return sent;
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
    final timestamp = _notificationTimeForDate(dateOnly);
    final expiresAt = timestamp.add(_retention);
    if (expiresAt.isBefore(now)) return false;

    final message = _dailyReportMessage(dateOnly, spending, other);
    final existingIndex = _notifications.indexWhere((item) => item.id == id);

    if (existingIndex == -1) {
      _notifications.add(
        SpendingNotification(
          id: id,
          type: SpendingNotificationType.dailyReport,
          title: _tr('Daily spending summary'),
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
      final title = _reportExpiresTitle(daysBefore);
      final message = _reportExpiresMessage(
        dailyNotification.reportDate!,
        daysBefore,
      );

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

  Future<bool> _upsertBudgetAdjustmentNotification({
    required SpendingProvider spending,
    required DateTime date,
    required DateTime now,
  }) async {
    final effectiveDate = DateTime(date.year, date.month, date.day);
    final adjustment = spending.getDailyBudgetAdjustmentForDate(effectiveDate);
    if (adjustment == null) return false;

    final summaryDate = _budgetSummaryDateForEffectiveDate(effectiveDate);
    final id = _dailyBudgetId(summaryDate);
    if (_deletedIds.contains(id)) return false;

    final timestamp = _notificationTimeForDate(summaryDate);
    final expiresAt = timestamp.add(_retention);
    if (expiresAt.isBefore(now)) return false;

    final title = _dailyBudgetTitle(adjustment);
    final message = _dailyBudgetMessage(adjustment);
    final type = adjustment.overspentYesterday
        ? SpendingNotificationType.budgetExceeded
        : SpendingNotificationType.budgetWarning;
    final existingIndex = _notifications.indexWhere((item) => item.id == id);

    if (existingIndex == -1) {
      _notifications.add(
        SpendingNotification(
          id: id,
          type: type,
          title: title,
          message: message,
          timestamp: timestamp,
          expiresAt: expiresAt,
          reportDate: effectiveDate,
        ),
      );

      if (_isSameDate(summaryDate, now) && !timestamp.isAfter(now)) {
        await NotificationService.showNotification(
          notificationKey: id,
          title: title,
          body: message,
          payload: id,
        );
      }
      return true;
    }

    final current = _notifications[existingIndex];
    if (current.type == type &&
        current.title == title &&
        current.message == message &&
        current.timestamp == timestamp &&
        current.expiresAt == expiresAt) {
      return false;
    }

    _notifications[existingIndex] = current.copyWith(
      type: type,
      title: title,
      message: message,
      timestamp: timestamp,
      expiresAt: expiresAt,
      reportDate: effectiveDate,
    );
    return true;
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
        _dailyNotificationHour,
      );
      return !timestamp.isAfter(now);
    });
  }

  Iterable<DateTime> _eligibleBudgetDates({
    required DateTime now,
    required SpendingProvider spending,
  }) sync* {
    if (!spending.hasPeriod || spending.monthlyBudget <= 0) return;

    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < _retention.inDays; i++) {
      final summaryDate = today.subtract(Duration(days: i));
      final effectiveDate = _budgetEffectiveDateForSummaryDate(summaryDate);
      if (spending.getDailyBudgetAdjustmentForDate(effectiveDate) != null) {
        yield effectiveDate;
      }
    }
  }

  DateTime? _latestEligibleReportDate({
    required DateTime now,
    required SpendingProvider spending,
    required OtherSpendingProvider other,
  }) {
    final dates = _eligibleReportDates(
      now: now,
      spending: spending,
      other: other,
    ).toList()..sort((a, b) => b.compareTo(a));
    return dates.isEmpty ? null : dates.first;
  }

  DateTime? _latestEligibleBudgetDate({
    required DateTime now,
    required SpendingProvider spending,
  }) {
    final dates = _eligibleBudgetDates(now: now, spending: spending).toList()
      ..sort((a, b) => b.compareTo(a));
    return dates.isEmpty ? null : dates.first;
  }

  SpendingNotification? _latestStoredNotification(
    bool Function(SpendingNotification item) test,
  ) {
    final matches = _notifications.where(test).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _scheduleUpcomingNotifications({
    required SpendingProvider spending,
    required OtherSpendingProvider other,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduledAt = _notificationTimeForDate(today);
    final todayId = _dailyReportId(today);

    if (spending.notificationPreferences.dailySummaryEnabled &&
        !_deletedIds.contains(todayId) &&
        scheduledAt.isAfter(now)) {
      await NotificationService.scheduleNotification(
        notificationKey: todayId,
        title: _tr('Daily spending summary'),
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
          title: _reportExpiresTitle(daysBefore),
          body: _reportExpiresMessage(
            dailyNotification.reportDate!,
            daysBefore,
          ),
          scheduledAt: reminderTime,
          payload: reminderId,
        );
      }
    }

    for (final notification in _notifications.where(
      (item) => item.type != SpendingNotificationType.dailyReport,
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

    return '${DateFormat('EEE, MMM d', _languageCode).format(date)} - $transactionCount ${_tr('Transactions').toLowerCase()} - ${_formatAmount(totalSpent)}';
  }

  String _dailyBudgetMessage(DailyBudgetAdjustment adjustment) {
    final allowance = _formatAmount(adjustment.currentAllowance);
    final balance = adjustment.cumulativeDifference;
    final balanceAmount = _formatAmount(balance.abs());
    if (adjustment.isOverBudget) {
      return _tr(
        'Through today, you are over budget by {deficit}. Your available budget for tomorrow is {allowance}.',
        {'deficit': balanceAmount, 'allowance': allowance},
      );
    }
    if (adjustment.isUnderBudget) {
      return _tr(
        'Through today, you are under budget by {surplus}. Your available budget for tomorrow is {allowance}.',
        {'surplus': balanceAmount, 'allowance': allowance},
      );
    }

    return _tr(
      'You are exactly on budget through today. Your available budget for tomorrow is {allowance}.',
      {'allowance': allowance},
    );
  }

  String _dailyBudgetTitle(DailyBudgetAdjustment adjustment) {
    if (adjustment.isOverBudget) {
      return _tr('Budget deficit remaining');
    }
    if (adjustment.isUnderBudget) {
      return _tr('Daily budget increased');
    }
    if (adjustment.overspentYesterday) {
      return _tr('Daily budget adjusted');
    }
    return _tr("Tomorrow's budget is ready");
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

  String _dailyBudgetId(DateTime date) =>
      'daily-budget-${DateFormat('yyyy-MM-dd').format(date)}';

  String _reminderId(String parentId, int daysBefore) =>
      '$parentId-reminder-$daysBefore';

  String _formatAmount(double amount) =>
      '${NumberFormat('#,##0.00').format(amount)} SAR';

  String _reportExpiresTitle(int daysBefore) {
    return _tr('Report expires in {count} day(s)', {'count': '$daysBefore'});
  }

  String _reportExpiresMessage(DateTime date, int daysBefore) {
    return _tr(
      'Your daily spending report for {date} will expire in {count} day(s). Download the PDF if you want to keep it.',
      {
        'date': DateFormat('yyyy-MM-dd', _languageCode).format(date),
        'count': '$daysBefore',
      },
    );
  }

  String _tr(String key, [Map<String, String> args = const {}]) {
    var value = DemoLocalization.translateCached(_languageCode, key);
    args.forEach((placeholder, replacement) {
      value = value.replaceAll('{$placeholder}', replacement);
    });
    return value;
  }

  DateTime _notificationTimeForDate(DateTime date) =>
      DateTime(date.year, date.month, date.day, _dailyNotificationHour);

  DateTime _budgetSummaryDateForEffectiveDate(DateTime effectiveDate) =>
      DateTime(
        effectiveDate.year,
        effectiveDate.month,
        effectiveDate.day,
      ).subtract(const Duration(days: 1));

  DateTime _budgetEffectiveDateForSummaryDate(DateTime summaryDate) =>
      DateTime(
        summaryDate.year,
        summaryDate.month,
        summaryDate.day,
      ).add(const Duration(days: 1));

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
