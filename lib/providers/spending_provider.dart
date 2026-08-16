import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/language_constants.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';

/// A single spending entry for a specific date
class SpendingEntry {
  final double amount; // already multiplied if qty was given
  final String? item;
  final String? bank;
  final String? bankAccountId;
  final int? qty;
  final String? category; // for analytics
  final bool createdByRecurring;
  final String? recurringPaymentId;
  final String? recurringOccurrenceKey;

  SpendingEntry({
    required this.amount,
    this.item,
    this.bank,
    this.bankAccountId,
    this.qty,
    this.category,
    this.createdByRecurring = false,
    this.recurringPaymentId,
    this.recurringOccurrenceKey,
  });

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'item': item,
    'bank': bank,
    'bankAccountId': bankAccountId,
    'qty': qty,
    'category': category,
    'createdByRecurring': createdByRecurring,
    'recurringPaymentId': recurringPaymentId,
    'recurringOccurrenceKey': recurringOccurrenceKey,
  };

  factory SpendingEntry.fromJson(Map<String, dynamic> json) => SpendingEntry(
    amount: (json['amount'] ?? 0).toDouble(),
    item: json['item'] as String?,
    bank: json['bank'] as String?,
    bankAccountId: json['bankAccountId'] as String?,
    qty: json['qty'] != null ? (json['qty'] as num).toInt() : null,
    category: json['category'] as String?,
    createdByRecurring: (json['createdByRecurring'] as bool?) ?? false,
    recurringPaymentId: json['recurringPaymentId'] as String?,
    recurringOccurrenceKey: json['recurringOccurrenceKey'] as String?,
  );
}

class CategorySpendingRecord {
  final DateTime date;
  final int index;
  final SpendingEntry entry;

  const CategorySpendingRecord({
    required this.date,
    required this.index,
    required this.entry,
  });
}

class DailyBudgetAdjustment {
  final DateTime date;
  final DateTime previousDate;
  final double previousAllowance;
  final double previousSpent;
  final double currentAllowance;
  final double cumulativeBudget;
  final double cumulativeSpent;
  final double baseDailyBudget;
  final double remainingBudget;
  final int remainingDays;

  const DailyBudgetAdjustment({
    required this.date,
    required this.previousDate,
    required this.previousAllowance,
    required this.previousSpent,
    required this.currentAllowance,
    required this.cumulativeBudget,
    required this.cumulativeSpent,
    required this.baseDailyBudget,
    required this.remainingBudget,
    required this.remainingDays,
  });

  bool get hadNoSpendingYesterday => previousSpent <= 0;
  bool get overspentYesterday => previousSpent > previousAllowance;
  bool get allowanceIncreased => currentAllowance > previousAllowance;
  double get cumulativeDifference => cumulativeBudget - cumulativeSpent;
  bool get isOverBudget => cumulativeDifference < 0;
  bool get isUnderBudget => cumulativeDifference > 0;
}

class RecurringPaymentCommitment {
  final String paymentId;
  final String title;
  final double amount;
  final DateTime dueDate;
  final String? category;
  final String? bank;
  final String? bankAccountId;

  const RecurringPaymentCommitment({
    required this.paymentId,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.category,
    this.bank,
    this.bankAccountId,
  });
}

class BudgetGuidanceSnapshot {
  final DateTime date;
  final double baseDailyBudget;
  final double dailyAllowance;
  final double spentToday;
  final double remainingTodayAllowance;
  final double remainingBudget;
  final int remainingDays;
  final double upcomingRecurringTotal;
  final List<RecurringPaymentCommitment> upcomingRecurringPayments;
  final double discretionaryRemaining;
  final double safeToSpendToday;
  final double safeToSpendUntilEndOfPeriod;
  final int? recoveryDays;
  final double projectedAllowanceAfterRecovery;
  final double tomorrowAllowanceIfNoMoreSpending;
  final double followingDayAllowanceIfNoSpendingTomorrow;
  final double recommendedDailyCap;
  final double dailyReductionNeeded;

  const BudgetGuidanceSnapshot({
    required this.date,
    required this.baseDailyBudget,
    required this.dailyAllowance,
    required this.spentToday,
    required this.remainingTodayAllowance,
    required this.remainingBudget,
    required this.remainingDays,
    required this.upcomingRecurringTotal,
    required this.upcomingRecurringPayments,
    required this.discretionaryRemaining,
    required this.safeToSpendToday,
    required this.safeToSpendUntilEndOfPeriod,
    required this.recoveryDays,
    required this.projectedAllowanceAfterRecovery,
    required this.tomorrowAllowanceIfNoMoreSpending,
    required this.followingDayAllowanceIfNoSpendingTomorrow,
    required this.recommendedDailyCap,
    required this.dailyReductionNeeded,
  });

  bool get isOverBudget => remainingBudget < 0;
  bool get hasUpcomingRecurringPayments => upcomingRecurringPayments.isNotEmpty;
  double get reservedForRecurring => upcomingRecurringTotal;
  double get overBudgetAmount => isOverBudget ? -remainingBudget : 0;
}

/// A single income entry (salary, bonus, side income, etc.)
class IncomeEntry {
  final double amount;
  final String? source;
  final String? note;

  IncomeEntry({required this.amount, this.source, this.note});

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'source': source,
    'note': note,
  };

  factory IncomeEntry.fromJson(Map<String, dynamic> json) => IncomeEntry(
    amount: (json['amount'] ?? 0).toDouble(),
    source: json['source'] as String?,
    note: json['note'] as String?,
  );
}

/// A bank account/payment source with the current available balance.
class BankAccount {
  final String id;
  final String name;
  final double balance;

  const BankAccount({
    required this.id,
    required this.name,
    required this.balance,
  });

  static String newId() => 'bank_${DateTime.now().microsecondsSinceEpoch}';

  BankAccount copyWith({String? id, String? name, double? balance}) {
    return BankAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'balance': balance};

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String? ?? '').trim();
    final fallbackId = name.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    return BankAccount(
      id: (json['id'] as String? ?? fallbackId).trim(),
      name: name,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

class NotificationPreferences {
  final bool dailySummaryEnabled;
  final bool includeBudgetContext;
  final bool includeBankContext;
  final bool includeOtherSpending;
  final bool notifyWhenNoSpending;

  const NotificationPreferences({
    this.dailySummaryEnabled = true,
    this.includeBudgetContext = true,
    this.includeBankContext = true,
    this.includeOtherSpending = true,
    this.notifyWhenNoSpending = true,
  });

  NotificationPreferences copyWith({
    bool? dailySummaryEnabled,
    bool? includeBudgetContext,
    bool? includeBankContext,
    bool? includeOtherSpending,
    bool? notifyWhenNoSpending,
  }) {
    return NotificationPreferences(
      dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
      includeBudgetContext: includeBudgetContext ?? this.includeBudgetContext,
      includeBankContext: includeBankContext ?? this.includeBankContext,
      includeOtherSpending: includeOtherSpending ?? this.includeOtherSpending,
      notifyWhenNoSpending: notifyWhenNoSpending ?? this.notifyWhenNoSpending,
    );
  }

  Map<String, dynamic> toJson() => {
    'dailySummaryEnabled': dailySummaryEnabled,
    'includeBudgetContext': includeBudgetContext,
    'includeBankContext': includeBankContext,
    'includeOtherSpending': includeOtherSpending,
    'notifyWhenNoSpending': notifyWhenNoSpending,
  };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      dailySummaryEnabled: (json['dailySummaryEnabled'] as bool?) ?? true,
      includeBudgetContext: (json['includeBudgetContext'] as bool?) ?? true,
      includeBankContext: (json['includeBankContext'] as bool?) ?? true,
      includeOtherSpending: (json['includeOtherSpending'] as bool?) ?? true,
      notifyWhenNoSpending: (json['notifyWhenNoSpending'] as bool?) ?? true,
    );
  }
}

enum RecurringFrequency { monthly, weekly }

/// Recurring payments like rent, gym, subscriptions
class RecurringPayment {
  final String id; // local id
  final String title;
  final double amount;
  final int dayOfMonth; // 1..31
  final RecurringFrequency frequency;
  final DateTime startDate;
  final String? category;
  final String? bank;
  final String? bankAccountId;
  final bool autoAdd; // if true, auto-add spending on due day
  final List<String> processedOccurrenceKeys;

  RecurringPayment({
    required this.id,
    required this.title,
    required this.amount,
    required this.dayOfMonth,
    this.frequency = RecurringFrequency.monthly,
    required this.startDate,
    this.category,
    this.bank,
    this.bankAccountId,
    this.autoAdd = false,
    this.processedOccurrenceKeys = const <String>[],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'dayOfMonth': dayOfMonth,
    'frequency': frequency.name,
    'startDate': startDate.toIso8601String(),
    'category': category,
    'bank': bank,
    'bankAccountId': bankAccountId,
    'autoAdd': autoAdd,
    'processedOccurrenceKeys': processedOccurrenceKeys,
  };

  factory RecurringPayment.fromJson(Map<String, dynamic> json) =>
      RecurringPayment(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] ?? 0).toDouble(),
        dayOfMonth: (json['dayOfMonth'] as num).toInt(),
        frequency: RecurringFrequency.values.firstWhere(
          (value) => value.name == (json['frequency'] as String?),
          orElse: () => RecurringFrequency.monthly,
        ),
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String)
            : DateTime.now(),
        category: json['category'] as String?,
        bank: json['bank'] as String?,
        bankAccountId: json['bankAccountId'] as String?,
        autoAdd: (json['autoAdd'] as bool?) ?? false,
        processedOccurrenceKeys:
            (json['processedOccurrenceKeys'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toList(),
      );

  RecurringPayment copyWith({
    String? id,
    String? title,
    double? amount,
    int? dayOfMonth,
    RecurringFrequency? frequency,
    DateTime? startDate,
    String? category,
    String? bank,
    String? bankAccountId,
    bool? autoAdd,
    List<String>? processedOccurrenceKeys,
  }) {
    return RecurringPayment(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      category: category ?? this.category,
      bank: bank ?? this.bank,
      bankAccountId: bankAccountId ?? this.bankAccountId,
      autoAdd: autoAdd ?? this.autoAdd,
      processedOccurrenceKeys:
          processedOccurrenceKeys ?? this.processedOccurrenceKeys,
    );
  }
}

class SpendingProvider extends ChangeNotifier {
  double _monthlyBudget = 0;

  /// dateKey -> total amount
  final Map<String, double> _dailySpendings = {};
  String _p(String uid, String key) => 'u:$uid:$key';

  String _stripPrefix(String uid, String fullKey) =>
      fullKey.replaceFirst('u:$uid:', '');

  /// dateKey -> list of entries
  final Map<String, List<SpendingEntry>> _dailyEntries = {};

  // --------- INCOME ---------
  /// dateKey -> list of income entries
  final Map<String, List<IncomeEntry>> _incomeByDate = {};
  double _periodIncomeTotal = 0;

  // --------- RECURRING PAYMENTS ---------
  final List<RecurringPayment> _recurringPayments = [];

  // --------- BANK ACCOUNTS / PAYMENT SOURCES ---------
  final List<BankAccount> _bankAccounts = [];

  NotificationPreferences _notificationPreferences =
      const NotificationPreferences();

  double _todayTotal = 0;
  double _periodTotal = 0;
  DateTime _today = DateTime.now();

  // budget period
  DateTime? _periodStart;
  DateTime? _periodEnd;

  // firestore
  String? _userId;
  bool _remoteLoaded = false;

  // -------- CATEGORY CANONICALIZATION (for Snack/snacks/SNACK, etc.) --------
  /// key (normalized, usually singular lowercase) -> canonical label (first form entered)
  final Map<String, String> _categoryCanon = {};

  String? _canonicalizeCategory(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();

    // Basic key
    String key = lower;

    // Simple singular form: remove trailing 's'
    String singularKey = lower.endsWith('s') && lower.length > 1
        ? lower.substring(0, lower.length - 1)
        : lower;

    // If we already know this exact key -> reuse canonical
    if (_categoryCanon.containsKey(key)) {
      return _categoryCanon[key];
    }

    // If we know the singular version -> reuse canonical
    if (_categoryCanon.containsKey(singularKey)) {
      return _categoryCanon[singularKey];
    }

    // New category -> store canonical as first seen spelling
    _categoryCanon[singularKey] = trimmed;
    if (key != singularKey) {
      _categoryCanon[key] = trimmed;
    }

    return trimmed;
  }

  // ✅ quantity rule: empty/null/0/not valid => 1 (never 0)
  int _effectiveQty(int? qty) {
    if (qty == null) return 1;
    if (qty <= 0) return 1;
    return qty;
  }

  /// ✅ For category autocomplete (YouTube-like suggestions)
  /// Returns unique previously used category labels (canonical), sorted.
  List<String> getAllUsedCategories() {
    final set = <String>{};

    // from canonical map
    for (final v in _categoryCanon.values) {
      final t = v.trim();
      if (t.isNotEmpty) set.add(t);
    }

    // from entries (in case canon map is empty)
    for (final entries in _dailyEntries.values) {
      for (final e in entries) {
        final c = e.category;
        if (c != null && c.trim().isNotEmpty) {
          set.add(c.trim());
        }
      }
    }

    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  String categoryLabelOf(SpendingEntry entry) {
    final raw = entry.category;
    if (raw == null || raw.trim().isEmpty) {
      return 'Uncategorized';
    }
    return raw.trim();
  }

  double get monthlyBudget => _monthlyBudget;
  double get todayTotal => _todayTotal;
  double get periodTotal => _periodTotal;
  DateTime? get periodStart => _periodStart;
  DateTime? get periodEnd => _periodEnd;
  bool get hasPeriod => _periodStart != null && _periodEnd != null;

  // income getters
  double get periodIncomeTotal => _periodIncomeTotal;

  /// Savings rate % = (Income - Expenses) / Income * 100
  double get savingsRatePercent {
    if (_periodIncomeTotal <= 0) return 0;
    final saved = _periodIncomeTotal - _periodTotal;
    return (saved / _periodIncomeTotal) * 100;
  }

  // recurring getters
  List<RecurringPayment> get recurringPayments =>
      List.unmodifiable(_recurringPayments);

  // bank account getters
  List<BankAccount> get bankAccounts => List.unmodifiable(_bankAccounts);

  double get totalBankBalance =>
      _bankAccounts.fold(0.0, (sum, account) => sum + account.balance);

  BankAccount? getBankAccountById(String? id) {
    final trimmed = id?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    for (final account in _bankAccounts) {
      if (account.id == trimmed) return account;
    }
    return null;
  }

  String? findBankAccountId({String? bankAccountId, String? bankName}) {
    final index = _findBankAccountIndex(
      bankAccountId: bankAccountId,
      bankName: bankName,
    );
    if (index == -1) return null;
    return _bankAccounts[index].id;
  }

  String? bankNameForId(String? bankAccountId) =>
      getBankAccountById(bankAccountId)?.name;

  NotificationPreferences get notificationPreferences =>
      _notificationPreferences;

  double get dailyAllowance => getDailyAllowanceForDate(DateTime.now());

  // --------------------------------------------------
  // load all LOCAL data
  // --------------------------------------------------
  Future<void> loadData(String uid) async {
    _userId = uid; // ✅ important
    final prefs = await SharedPreferences.getInstance();

    _monthlyBudget = prefs.getDouble(_p(uid, 'monthlyBudget')) ?? 0;
    _notificationPreferences = _loadNotificationPreferencesLocal(prefs, uid);

    _dailySpendings.clear();
    _dailyEntries.clear();
    _incomeByDate.clear();
    _recurringPayments.clear();
    _bankAccounts.clear();
    _categoryCanon.clear();

    for (final key in prefs.getKeys().where((k) => k.startsWith('u:$uid:'))) {
      final localKey = _stripPrefix(uid, key);
      // ----- Spendings -----
      if (localKey.startsWith('spend_')) {
        final amount = prefs.getDouble(key) ?? 0; // keep `key` here (full key)
        final dateStr = localKey.replaceFirst('spend_', '');
        _dailySpendings[dateStr] = amount;
      }

      if (localKey.startsWith('spendEntries_')) {
        final dateStr = localKey.replaceFirst('spendEntries_', '');
        final raw = prefs.getString(key);
        if (raw != null && raw.isNotEmpty) {
          final List decoded = jsonDecode(raw);
          _dailyEntries[dateStr] = decoded.map((e) {
            final entry = SpendingEntry.fromJson(e);
            return SpendingEntry(
              amount: entry.amount,
              item: entry.item,
              bank: entry.bank,
              bankAccountId: entry.bankAccountId,
              qty: entry.qty != null ? _effectiveQty(entry.qty) : 1,
              category: _canonicalizeCategory(entry.category),
              createdByRecurring: entry.createdByRecurring,
              recurringPaymentId: entry.recurringPaymentId,
              recurringOccurrenceKey: entry.recurringOccurrenceKey,
            );
          }).toList();
        }
      }

      if (localKey.startsWith('incomeEntries_')) {
        final dateStr = localKey.replaceFirst('incomeEntries_', '');
        final raw = prefs.getString(key);
        if (raw != null && raw.isNotEmpty) {
          final List decoded = jsonDecode(raw);
          _incomeByDate[dateStr] = decoded
              .map((e) => IncomeEntry.fromJson(e))
              .toList();
        }
      }
    }

    final bankAccountsRaw = prefs.getString(_p(uid, 'bankAccounts'));
    if (bankAccountsRaw != null && bankAccountsRaw.isNotEmpty) {
      try {
        final List decoded = jsonDecode(bankAccountsRaw);
        _bankAccounts.addAll(
          _normalizeBankAccounts(
            decoded.whereType<Map>().map(
              (e) => BankAccount.fromJson(Map<String, dynamic>.from(e)),
            ),
          ),
        );
      } catch (_) {
        // ignore corrupt data
      }
    }

    // load period if exists, else current month
    final periodStartStr = prefs.getString(_p(uid, 'period_start'));
    final periodEndStr = prefs.getString(_p(uid, 'period_end'));

    if (periodStartStr != null && periodEndStr != null) {
      _periodStart = DateTime.parse(periodStartStr);
      _periodEnd = DateTime.parse(periodEndStr);
    } else {
      _setCurrentMonthPeriodInternal();
    }

    // load recurring payments
    final recurringRaw = prefs.getString(_p(uid, 'recurringPayments'));

    if (recurringRaw != null && recurringRaw.isNotEmpty) {
      try {
        final List decoded = jsonDecode(recurringRaw);
        _recurringPayments.addAll(
          decoded.map((e) {
            final rp = RecurringPayment.fromJson(e);
            return RecurringPayment(
              id: rp.id,
              title: rp.title,
              amount: rp.amount,
              dayOfMonth: rp.dayOfMonth,
              frequency: rp.frequency,
              startDate: _dateOnly(rp.startDate),
              category: _canonicalizeCategory(rp.category),
              bank: rp.bank,
              bankAccountId: rp.bankAccountId,
              autoAdd: rp.autoAdd,
              processedOccurrenceKeys: rp.processedOccurrenceKeys,
            );
          }).toList(),
        );
      } catch (_) {
        // ignore corrupt data
      }
    }

    final todayKey = _dateKey(DateTime.now());
    _todayTotal = _dailySpendings[todayKey] ?? 0;
    _today = DateTime.now();

    _periodTotal = _calculateTotalForPeriod();
    _periodIncomeTotal = _calculateIncomeTotalForPeriod();

    notifyListeners();
  }

  // --------------------------------------------------
  // connect to FIRESTORE when user is known
  // --------------------------------------------------
  Future<void> attachUser(String? uid) async {
    // If logging out
    if (uid == null) {
      _userId = null;
      _remoteLoaded = false;

      // Clear local in-memory values so UI doesn't show previous user
      _monthlyBudget = 0;
      _notificationPreferences = const NotificationPreferences();
      _dailySpendings.clear();
      _dailyEntries.clear();
      _incomeByDate.clear();
      _recurringPayments.clear();
      _bankAccounts.clear();
      _categoryCanon.clear();
      _todayTotal = 0;
      _periodTotal = 0;
      _periodIncomeTotal = 0;
      _periodStart = null;
      _periodEnd = null;

      notifyListeners();
      return;
    }

    // If switching users
    if (_userId != null && _userId != uid) {
      _remoteLoaded = false;

      // Clear local in-memory values immediately
      _monthlyBudget = 0;
      _notificationPreferences = const NotificationPreferences();
      _dailySpendings.clear();
      _dailyEntries.clear();
      _incomeByDate.clear();
      _recurringPayments.clear();
      _bankAccounts.clear();
      _categoryCanon.clear();
      _todayTotal = 0;
      _periodTotal = 0;
      _periodIncomeTotal = 0;
      _periodStart = null;
      _periodEnd = null;

      notifyListeners(); // ✅ important: update UI right away
    }

    // If already loaded for same user
    if (_userId == uid && _remoteLoaded) return;

    _userId = uid;

    try {
      final meta = await FirestoreService.instance.getUserMeta(uid);
      if (meta != null) {
        if (meta['monthlyBudget'] != null) {
          _monthlyBudget = (meta['monthlyBudget'] as num).toDouble();
        }
        if (meta['periodStart'] != null) {
          _periodStart = DateTime.parse(meta['periodStart'] as String);
        }
        if (meta['periodEnd'] != null) {
          _periodEnd = DateTime.parse(meta['periodEnd'] as String);
        }
        final notificationPrefsRaw = meta['notificationPreferences'];
        if (notificationPrefsRaw is Map) {
          _notificationPreferences = NotificationPreferences.fromJson(
            Map<String, dynamic>.from(notificationPrefsRaw),
          );
        }
        final bankAccountsRaw = meta['bankAccounts'];
        if (bankAccountsRaw is List) {
          _bankAccounts
            ..clear()
            ..addAll(
              _normalizeBankAccounts(
                bankAccountsRaw.whereType<Map>().map(
                  (e) => BankAccount.fromJson(Map<String, dynamic>.from(e)),
                ),
              ),
            );
        }
        final recurringPaymentsRaw = meta['recurringPayments'];
        if (recurringPaymentsRaw is List) {
          _recurringPayments
            ..clear()
            ..addAll(
              recurringPaymentsRaw.whereType<Map>().map((e) {
                final payment = RecurringPayment.fromJson(
                  Map<String, dynamic>.from(e),
                );
                return payment.copyWith(
                  startDate: _dateOnly(payment.startDate),
                  category: _canonicalizeCategory(payment.category),
                );
              }),
            );
        }
      }

      final days = await FirestoreService.instance.getAllDays(uid);
      for (final d in days) {
        final data = d.data();
        final dateKey = data['date'] as String;

        final entriesRaw = (data['entries'] as List<dynamic>? ?? []);
        final entries = entriesRaw.map((e) {
          final entry = SpendingEntry.fromJson(e as Map<String, dynamic>);
          return SpendingEntry(
            amount: entry.amount,
            item: entry.item,
            bank: entry.bank,
            bankAccountId: entry.bankAccountId,
            qty: entry.qty != null ? _effectiveQty(entry.qty) : 1,
            category: _canonicalizeCategory(entry.category),
            createdByRecurring: entry.createdByRecurring,
            recurringPaymentId: entry.recurringPaymentId,
            recurringOccurrenceKey: entry.recurringOccurrenceKey,
          );
        }).toList();

        _dailyEntries[dateKey] = entries;

        final total =
            (data['total'] as num?)?.toDouble() ??
            entries.fold(0.0, (sum, e) => sum! + e.amount);

        _dailySpendings[dateKey] = total!;
      }

      // if no period from remote, use current month
      if (_periodStart == null || _periodEnd == null) {
        _setCurrentMonthPeriodInternal();
      }

      _today = DateTime.now();
      _todayTotal = _dailySpendings[_dateKey(_today)] ?? 0;

      _periodTotal = _calculateTotalForPeriod();
      _periodIncomeTotal = _calculateIncomeTotalForPeriod();

      _remoteLoaded = true;

      await _saveAllLocal();
      notifyListeners();
    } catch (_) {
      // keep local if remote fails
    }
  }

  // --------------------------------------------------
  // set monthly budget
  // --------------------------------------------------
  Future<void> setMonthlyBudget(
    double value, {
    List<BankAccount>? bankAccounts,
  }) async {
    _monthlyBudget = value;
    if (bankAccounts != null) {
      _bankAccounts
        ..clear()
        ..addAll(_normalizeBankAccounts(bankAccounts));
    }
    await _saveMetaLocal();
    await _saveMetaRemote();
    notifyListeners();
  }

  Future<void> setBankAccounts(List<BankAccount> bankAccounts) async {
    _bankAccounts
      ..clear()
      ..addAll(_normalizeBankAccounts(bankAccounts));
    await _saveBankAccountsLocal();
    await _saveBankAccountsRemote();
    notifyListeners();
  }

  Future<void> setNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    _notificationPreferences = preferences;
    await _saveMetaLocal();
    await _saveMetaRemote();
    notifyListeners();
  }

  // --------------------------------------------------
  // period methods
  // --------------------------------------------------
  Future<void> useCurrentMonthPeriod() async {
    _setCurrentMonthPeriodInternal();
    await _saveMetaLocal();
    await _saveMetaRemote();
    _periodTotal = _calculateTotalForPeriod();
    _periodIncomeTotal = _calculateIncomeTotalForPeriod();
    notifyListeners();
  }

  Future<void> setBudgetPeriod(DateTime start, DateTime end) async {
    if (start.isAfter(end)) {
      final tmp = start;
      start = end;
      end = tmp;
    }
    _periodStart = DateTime(start.year, start.month, start.day);
    _periodEnd = DateTime(end.year, end.month, end.day);
    await _saveMetaLocal();
    await _saveMetaRemote();
    _periodTotal = _calculateTotalForPeriod();
    _periodIncomeTotal = _calculateIncomeTotalForPeriod();
    notifyListeners();
  }

  void _setCurrentMonthPeriodInternal() {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final last = DateTime(now.year, now.month + 1, 0);
    _periodStart = first;
    _periodEnd = last;
  }

  // --------------------------------------------------
  // add / replace spending for a specific date
  // --------------------------------------------------
  Future<void> addSpendingForDate(
    DateTime date,
    double amount, {
    bool replace = false,
    String? item,
    String? bank,
    String? bankAccountId,
    int? qty,
    String? category,
    bool createdByRecurring = false,
    String? recurringPaymentId,
    String? recurringOccurrenceKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _dateKey(date);
    final previousEntries = List<SpendingEntry>.from(
      _dailyEntries[dateKey] ?? const <SpendingEntry>[],
    );

    final int finalQty = _effectiveQty(qty);

    // multiply by quantity (always at least 1)
    final double totalAmount = amount * finalQty;

    final normalizedCategory = _canonicalizeCategory(category);
    final resolvedBankAccountId = findBankAccountId(
      bankAccountId: bankAccountId,
      bankName: bank,
    );
    final resolvedBank = resolvedBankAccountId != null
        ? bankNameForId(resolvedBankAccountId)
        : _trimToNull(bank);
    final newEntry = SpendingEntry(
      amount: totalAmount,
      item: item,
      bank: resolvedBank,
      bankAccountId: resolvedBankAccountId,
      qty: finalQty,
      category: normalizedCategory,
      createdByRecurring: createdByRecurring,
      recurringPaymentId: recurringPaymentId,
      recurringOccurrenceKey: recurringOccurrenceKey,
    );

    if (replace) {
      _dailyEntries[dateKey] = [newEntry];
    } else {
      final current = List<SpendingEntry>.from(
        _dailyEntries[dateKey] ?? const <SpendingEntry>[],
      );
      current.add(newEntry);
      _dailyEntries[dateKey] = current;
    }

    final balancesChanged = _syncBankBalancesForEntryChange(
      previousEntries: previousEntries,
      nextEntries: _dailyEntries[dateKey] ?? const <SpendingEntry>[],
    );
    await _recalcAndPersistDay(dateKey, prefs);
    if (balancesChanged) {
      await _saveBankAccountsLocal(prefs);
      await _saveBankAccountsRemote();
    }
    await _saveDayRemote(dateKey);
  }

  /// old behavior - add to today
  Future<void> addSpending(double amount) async {
    await addSpendingForDate(DateTime.now(), amount);
  }

  // --------------------------------------------------
  // INCOME METHODS
  // --------------------------------------------------
  Future<void> addIncomeForDate(
    DateTime date,
    double amount, {
    String? source,
    String? note,
  }) async {
    if (amount <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _dateKey(date);

    final list = List<IncomeEntry>.from(
      _incomeByDate[dateKey] ?? const <IncomeEntry>[],
    );
    list.add(IncomeEntry(amount: amount, source: source, note: note));
    _incomeByDate[dateKey] = list;

    await _recalcAndPersistIncomeDay(dateKey, prefs);
  }

  double getIncomeForDate(DateTime date) {
    final key = _dateKey(date);
    final list = _incomeByDate[key] ?? const <IncomeEntry>[];
    return list.fold(0.0, (sum, e) => sum + e.amount);
  }

  List<IncomeEntry> getIncomeEntriesForDate(DateTime date) {
    final key = _dateKey(date);
    return _incomeByDate[key] ?? const [];
  }

  Future<void> removeIncomeEntryForDate({
    required DateTime date,
    required int index,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _dateKey(date);
    final list = _incomeByDate[dateKey];
    if (list == null || index < 0 || index >= list.length) return;

    list.removeAt(index);
    if (list.isEmpty) {
      _incomeByDate.remove(dateKey);
    } else {
      _incomeByDate[dateKey] = List<IncomeEntry>.from(list);
    }

    await _recalcAndPersistIncomeDay(dateKey, prefs);
  }

  // --------------------------------------------------
  // RECURRING PAYMENTS METHODS
  // --------------------------------------------------
  Future<void> addRecurringPayment({
    required String title,
    required double amount,
    required int dayOfMonth,
    RecurringFrequency frequency = RecurringFrequency.monthly,
    DateTime? startDate,
    String? category,
    String? bank,
    String? bankAccountId,
    bool autoAdd = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final normalizedCategory = _canonicalizeCategory(category);
    final resolvedBankAccountId = findBankAccountId(
      bankAccountId: bankAccountId,
      bankName: bank,
    );
    final resolvedBank = resolvedBankAccountId != null
        ? bankNameForId(resolvedBankAccountId)
        : _trimToNull(bank);

    _recurringPayments.add(
      RecurringPayment(
        id: id,
        title: title,
        amount: amount,
        dayOfMonth: dayOfMonth,
        frequency: frequency,
        startDate: _dateOnly(startDate ?? DateTime.now()),
        category: normalizedCategory,
        bank: resolvedBank,
        bankAccountId: resolvedBankAccountId,
        autoAdd: autoAdd,
      ),
    );

    await _saveRecurringLocal(prefs);
    await _saveRecurringRemote();
    await _scheduleRecurringReminderNotifications();
    notifyListeners();
  }

  Future<void> updateRecurringPayment({
    required String id,
    required String title,
    required double amount,
    required int dayOfMonth,
    required RecurringFrequency frequency,
    required DateTime startDate,
    String? category,
    String? bank,
    String? bankAccountId,
    bool autoAdd = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final index = _recurringPayments.indexWhere((payment) => payment.id == id);
    if (index == -1) return;

    final previous = _recurringPayments[index];
    await _cancelRecurringReminderNotification(previous);

    final normalizedCategory = _canonicalizeCategory(category);
    final resolvedBankAccountId = findBankAccountId(
      bankAccountId: bankAccountId,
      bankName: bank,
    );
    final resolvedBank = resolvedBankAccountId != null
        ? bankNameForId(resolvedBankAccountId)
        : _trimToNull(bank);

    _recurringPayments[index] = previous.copyWith(
      title: title,
      amount: amount,
      dayOfMonth: dayOfMonth,
      frequency: frequency,
      startDate: _dateOnly(startDate),
      category: normalizedCategory,
      bank: resolvedBank,
      bankAccountId: resolvedBankAccountId,
      autoAdd: autoAdd,
    );

    await _saveRecurringLocal(prefs);
    await _saveRecurringRemote();
    await _scheduleRecurringReminderNotifications();
    notifyListeners();
  }

  Future<void> removeRecurringPayment(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final index = _recurringPayments.indexWhere((payment) => payment.id == id);
    if (index == -1) return;

    final payment = _recurringPayments[index];
    await _cancelRecurringReminderNotification(payment);
    _recurringPayments.removeAt(index);
    await _saveRecurringLocal(prefs);
    await _saveRecurringRemote();
    await _scheduleRecurringReminderNotifications();
    notifyListeners();
  }

  DateTime getNextDueDate(RecurringPayment p, {DateTime? from}) {
    final fromDate = _dateOnly(from ?? DateTime.now());
    final startDate = _dateOnly(p.startDate);

    if (p.frequency == RecurringFrequency.weekly) {
      if (!fromDate.isAfter(startDate)) return startDate;
      final daysDiff = fromDate.difference(startDate).inDays;
      final weeksOffset = (daysDiff / 7).ceil();
      return startDate.add(Duration(days: weeksOffset * 7));
    }

    var candidate = _buildMonthlyOccurrenceDate(
      year: fromDate.year,
      month: fromDate.month,
      dayOfMonth: p.dayOfMonth,
    );
    if (candidate.isBefore(startDate) || candidate.isBefore(fromDate)) {
      final nextMonth = DateTime(fromDate.year, fromDate.month + 1, 1);
      candidate = _buildMonthlyOccurrenceDate(
        year: nextMonth.year,
        month: nextMonth.month,
        dayOfMonth: p.dayOfMonth,
      );
    }
    while (candidate.isBefore(startDate)) {
      final nextMonth = DateTime(candidate.year, candidate.month + 1, 1);
      candidate = _buildMonthlyOccurrenceDate(
        year: nextMonth.year,
        month: nextMonth.month,
        dayOfMonth: p.dayOfMonth,
      );
    }
    return candidate;
  }

  /// Upcoming recurring within [daysAhead]
  List<RecurringPayment> getUpcomingRecurringPayments({int daysAhead = 7}) {
    final now = DateTime.now();
    final todayDateOnly = DateTime(now.year, now.month, now.day);
    final List<RecurringPayment> result = [];

    for (final p in _recurringPayments) {
      final due = getNextDueDate(p);
      final diffDays = due.difference(todayDateOnly).inDays;
      if (diffDays >= 0 && diffDays <= daysAhead) {
        result.add(p);
      }
    }

    result.sort((a, b) {
      final ad = getNextDueDate(a);
      final bd = getNextDueDate(b);
      return ad.compareTo(bd);
    });
    return result;
  }

  List<RecurringPaymentCommitment> getUpcomingRecurringCommitmentsForPeriod({
    DateTime? from,
  }) {
    if (_periodStart == null || _periodEnd == null) return const [];

    final start = _dateOnly(from ?? DateTime.now());
    final normalizedStart = start.isBefore(_dateOnly(_periodStart!))
        ? _dateOnly(_periodStart!)
        : start;
    final end = _dateOnly(_periodEnd!);
    final commitments = <RecurringPaymentCommitment>[];

    for (final payment in _recurringPayments) {
      final processedKeys = payment.processedOccurrenceKeys.toSet();
      var dueDate = getNextDueDate(payment, from: normalizedStart);

      while (!dueDate.isAfter(end)) {
        final occurrenceKey = _dateKey(dueDate);
        if (!processedKeys.contains(occurrenceKey) &&
            !_hasRecurringOccurrenceRecorded(payment, dueDate, occurrenceKey)) {
          commitments.add(
            RecurringPaymentCommitment(
              paymentId: payment.id,
              title: payment.title,
              amount: payment.amount,
              dueDate: dueDate,
              category: payment.category,
              bank: payment.bank,
              bankAccountId: payment.bankAccountId,
            ),
          );
        }

        final nextDueDate = getNextDueDate(
          payment,
          from: dueDate.add(const Duration(days: 1)),
        );
        if (!nextDueDate.isAfter(dueDate)) break;
        dueDate = nextDueDate;
      }
    }

    commitments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return commitments;
  }

  double getUpcomingRecurringTotalForPeriod({DateTime? from}) {
    return getUpcomingRecurringCommitmentsForPeriod(
      from: from,
    ).fold(0.0, (sum, payment) => sum + payment.amount);
  }

  Future<void> processRecurringPayments({DateTime? now}) async {
    final currentDate = _dateOnly(now ?? DateTime.now());
    final generatedToday = <RecurringPayment>[];
    final generatedMissed = <RecurringPayment>[];
    var changed = false;

    for (var index = 0; index < _recurringPayments.length; index++) {
      final payment = _recurringPayments[index];
      final dueOccurrences = _dueOccurrencesUpTo(payment, currentDate);
      final processedKeys = payment.processedOccurrenceKeys.toSet();

      for (final dueDate in dueOccurrences) {
        final occurrenceKey = _dateKey(dueDate);
        if (processedKeys.contains(occurrenceKey)) continue;

        if (_hasRecurringOccurrenceRecorded(payment, dueDate, occurrenceKey)) {
          processedKeys.add(occurrenceKey);
          changed = true;
          continue;
        }

        if (payment.autoAdd) {
          await addSpendingForDate(
            dueDate,
            payment.amount,
            item: payment.title,
            bank: payment.bank,
            bankAccountId: payment.bankAccountId,
            category: payment.category,
            qty: 1,
            createdByRecurring: true,
            recurringPaymentId: payment.id,
            recurringOccurrenceKey: occurrenceKey,
          );
          if (_isSameDate(dueDate, currentDate)) {
            generatedToday.add(payment);
          } else {
            generatedMissed.add(payment);
          }
          processedKeys.add(occurrenceKey);
          changed = true;
        }
      }

      _recurringPayments[index] = payment.copyWith(
        processedOccurrenceKeys: processedKeys.toList()..sort(),
      );
    }

    if (changed) {
      final prefs = await SharedPreferences.getInstance();
      await _saveRecurringLocal(prefs);
      await _saveRecurringRemote();
    }

    await _scheduleRecurringReminderNotifications(referenceDate: currentDate);
    await _notifyRecurringProcessingResults(
      generatedToday: generatedToday,
      generatedMissed: generatedMissed,
      referenceDate: currentDate,
    );
    notifyListeners();
  }

  Future<void> processRecurringForToday() async {
    await processRecurringPayments();
  }

  DateTime _buildMonthlyOccurrenceDate({
    required int year,
    required int month,
    required int dayOfMonth,
  }) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final safeDay = dayOfMonth.clamp(1, lastDayOfMonth);
    return DateTime(year, month, safeDay);
  }

  List<DateTime> _dueOccurrencesUpTo(
    RecurringPayment payment,
    DateTime upToDate,
  ) {
    final results = <DateTime>[];
    final startDate = _dateOnly(payment.startDate);
    final normalizedEnd = _dateOnly(upToDate);
    if (startDate.isAfter(normalizedEnd)) return results;

    if (payment.frequency == RecurringFrequency.weekly) {
      var due = startDate;
      while (!due.isAfter(normalizedEnd)) {
        results.add(due);
        due = due.add(const Duration(days: 7));
      }
      return results;
    }

    var cursor = DateTime(startDate.year, startDate.month, 1);
    final endMonth = DateTime(normalizedEnd.year, normalizedEnd.month, 1);
    while (!cursor.isAfter(endMonth)) {
      final due = _buildMonthlyOccurrenceDate(
        year: cursor.year,
        month: cursor.month,
        dayOfMonth: payment.dayOfMonth,
      );
      if (!due.isBefore(startDate) && !due.isAfter(normalizedEnd)) {
        results.add(due);
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return results;
  }

  String _recurringReminderNotificationKey(
    RecurringPayment payment,
    DateTime dueDate,
  ) => 'recurring-reminder-${payment.id}-${_dateKey(dueDate)}';

  bool _hasRecurringOccurrenceRecorded(
    RecurringPayment payment,
    DateTime dueDate,
    String occurrenceKey,
  ) {
    final entries = _dailyEntries[_dateKey(dueDate)] ?? const <SpendingEntry>[];
    for (final entry in entries) {
      if (entry.recurringPaymentId == payment.id &&
          entry.recurringOccurrenceKey == occurrenceKey) {
        return true;
      }
      if (!entry.createdByRecurring &&
          (entry.item ?? '').trim() == payment.title.trim() &&
          entry.amount == payment.amount &&
          (entry.bankAccountId ?? '') == (payment.bankAccountId ?? '') &&
          (entry.category ?? '') == (payment.category ?? '') &&
          (entry.qty ?? 1) == 1) {
        return true;
      }
    }
    return false;
  }

  Future<void> _cancelRecurringReminderNotification(
    RecurringPayment payment,
  ) async {
    final nextDueDate = getNextDueDate(payment);
    await NotificationService.cancelNotificationByKey(
      _recurringReminderNotificationKey(payment, nextDueDate),
    );
  }

  Future<void> _scheduleRecurringReminderNotifications({
    DateTime? referenceDate,
  }) async {
    final now = referenceDate ?? DateTime.now();
    for (final payment in _recurringPayments) {
      final dueDate = getNextDueDate(payment, from: now);
      final reminderAt = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        9,
      ).subtract(const Duration(days: 1));
      final notificationKey = _recurringReminderNotificationKey(
        payment,
        dueDate,
      );

      if (reminderAt.isAfter(now)) {
        final title = await getTranslatedForCurrentLocale(
          'Upcoming recurring payment',
        );
        await NotificationService.scheduleNotification(
          notificationKey: notificationKey,
          title: title,
          body:
              '${payment.title} is due on ${_dateKey(dueDate)} for ${payment.amount.toStringAsFixed(2)} SAR.',
          scheduledAt: reminderAt,
          payload: notificationKey,
        );
      } else {
        await NotificationService.cancelNotificationByKey(notificationKey);
      }
    }
  }

  Future<void> _notifyRecurringProcessingResults({
    required List<RecurringPayment> generatedToday,
    required List<RecurringPayment> generatedMissed,
    required DateTime referenceDate,
  }) async {
    if (generatedToday.isEmpty && generatedMissed.isEmpty) return;

    if (generatedToday.isNotEmpty) {
      final title = await getTranslatedForCurrentLocale(
        generatedToday.length == 1
            ? 'Recurring payment added'
            : 'Recurring payments added',
      );
      final body = generatedToday.length == 1
          ? '${generatedToday.first.title} was added automatically for ${_dateKey(referenceDate)}.'
          : '${generatedToday.length} recurring payments were added automatically for ${_dateKey(referenceDate)}.';
      await NotificationService.showNotification(
        notificationKey: 'recurring-processed-today-${_dateKey(referenceDate)}',
        title: title,
        body: body,
      );
    }

    if (generatedMissed.isNotEmpty) {
      final title = await getTranslatedForCurrentLocale(
        generatedMissed.length == 1
            ? 'Missed recurring payment processed'
            : 'Missed recurring payments processed',
      );
      final body = generatedMissed.length == 1
          ? '${generatedMissed.first.title} was added from a missed due date.'
          : '${generatedMissed.length} missed recurring payments were added automatically.';
      await NotificationService.showNotification(
        notificationKey:
            'recurring-processed-missed-${_dateKey(referenceDate)}',
        title: title,
        body: body,
      );
    }
  }

  Future<void> _saveRecurringRemote() async {
    await _saveMetaRemote();
  }

  // --------------------------------------------------
  // edit an existing entry (by index)
  // --------------------------------------------------
  Future<void> saveEditedEntryForDate({
    required DateTime originalDate,
    required DateTime newDate,
    required int index,
    required double amount,
    String? item,
    String? bank,
    String? bankAccountId,
    int? qty,
    String? category,
  }) async {
    final normalizedOriginalDate = DateTime(
      originalDate.year,
      originalDate.month,
      originalDate.day,
    );
    final normalizedNewDate = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
    );

    if (normalizedOriginalDate == normalizedNewDate) {
      await updateEntryForDate(
        date: normalizedOriginalDate,
        index: index,
        amount: amount,
        item: item,
        bank: bank,
        bankAccountId: bankAccountId,
        qty: qty,
        category: category,
      );
      return;
    }

    final existingEntries = getEntriesForDate(normalizedOriginalDate);
    if (index < 0 || index >= existingEntries.length) return;

    await removeEntryForDate(date: normalizedOriginalDate, index: index);
    await addSpendingForDate(
      normalizedNewDate,
      amount,
      replace: false,
      item: item,
      bank: bank,
      bankAccountId: bankAccountId,
      qty: qty,
      category: category,
    );
  }

  Future<void> updateEntryForDate({
    required DateTime date,
    required int index,
    required double amount,
    String? item,
    String? bank,
    String? bankAccountId,
    int? qty,
    String? category,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _dateKey(date);

    final list = _dailyEntries[dateKey];
    if (list == null || index < 0 || index >= list.length) return;
    final previousEntries = List<SpendingEntry>.from(list);

    final int finalQty = _effectiveQty(qty);

    final double totalAmount = amount * finalQty;

    final normalizedCategory = _canonicalizeCategory(
      category ?? list[index].category,
    );
    final resolvedBankAccountId = findBankAccountId(
      bankAccountId: bankAccountId,
      bankName: bank,
    );
    final resolvedBank = resolvedBankAccountId != null
        ? bankNameForId(resolvedBankAccountId)
        : _trimToNull(bank);

    list[index] = SpendingEntry(
      amount: totalAmount,
      item: item,
      bank: resolvedBank,
      bankAccountId: resolvedBankAccountId,
      qty: finalQty,
      category: normalizedCategory,
    );

    _dailyEntries[dateKey] = List<SpendingEntry>.from(list);
    final balancesChanged = _syncBankBalancesForEntryChange(
      previousEntries: previousEntries,
      nextEntries: _dailyEntries[dateKey] ?? const <SpendingEntry>[],
    );
    await _recalcAndPersistDay(dateKey, prefs);
    if (balancesChanged) {
      await _saveBankAccountsLocal(prefs);
      await _saveBankAccountsRemote();
    }
    await _saveDayRemote(dateKey);
  }

  // --------------------------------------------------
  // remove entry
  // --------------------------------------------------
  Future<void> removeEntryForDate({
    required DateTime date,
    required int index,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _dateKey(date);

    final list = _dailyEntries[dateKey];
    if (list == null || index < 0 || index >= list.length) return;

    final previousEntries = List<SpendingEntry>.from(list);
    list.removeAt(index);

    if (list.isEmpty) {
      _dailyEntries.remove(dateKey);
      _dailySpendings.remove(dateKey);
      if (_userId == null) {
        await prefs.remove('spend_$dateKey');
        await prefs.remove('spendEntries_$dateKey');
      } else {
        final uid = _userId!;
        await prefs.remove(_p(uid, 'spend_$dateKey'));
        await prefs.remove(_p(uid, 'spendEntries_$dateKey'));
      }
      // remote: set empty day
      await _saveDayRemote(dateKey);
    } else {
      _dailyEntries[dateKey] = List<SpendingEntry>.from(list);
      await _recalcAndPersistDay(dateKey, prefs);
      await _saveDayRemote(dateKey);
    }

    final balancesChanged = _syncBankBalancesForEntryChange(
      previousEntries: previousEntries,
      nextEntries: _dailyEntries[dateKey] ?? const <SpendingEntry>[],
    );
    if (balancesChanged) {
      await _saveBankAccountsLocal(prefs);
      await _saveBankAccountsRemote();
    }

    _periodTotal = _calculateTotalForPeriod();
    notifyListeners();
  }

  // --------------------------------------------------
  // helper to recalc/save day & period, notify & maybe alert
  // --------------------------------------------------
  Future<void> _recalcAndPersistDay(
    String dateKey,
    SharedPreferences prefs,
  ) async {
    final dayEntries = _dailyEntries[dateKey] ?? const <SpendingEntry>[];
    final double newTotal = dayEntries.fold(0.0, (sum, e) => sum + e.amount);

    _dailySpendings[dateKey] = newTotal;

    final entriesJson = jsonEncode(dayEntries.map((e) => e.toJson()).toList());
    if (_userId == null) return;
    final uid = _userId!;
    await prefs.setDouble(_p(uid, 'spend_$dateKey'), newTotal);
    await prefs.setString(_p(uid, 'spendEntries_$dateKey'), entriesJson);

    if (_dateKey(_today) == dateKey) {
      _todayTotal = newTotal;
    }

    _periodTotal = _calculateTotalForPeriod();

    final affectedDate = _tryParseDateKey(dateKey);
    final allowance = affectedDate == null
        ? 0.0
        : getDailyAllowanceForDate(affectedDate);
    if (allowance > 0 && newTotal > allowance) {
      await NotificationService.showOverSpendNotification(
        todayTotal: newTotal,
        allowed: allowance,
      );
    }

    notifyListeners();
  }

  Future<void> _recalcAndPersistIncomeDay(
    String dateKey,
    SharedPreferences prefs,
  ) async {
    final dayEntries = _incomeByDate[dateKey] ?? const <IncomeEntry>[];
    final double newTotal = dayEntries.fold(0.0, (sum, e) => sum + e.amount);

    if (_userId == null) return;
    final uid = _userId!;
    await prefs.setDouble(_p(uid, 'income_$dateKey'), newTotal);
    await prefs.setString(
      _p(uid, 'incomeEntries_$dateKey'),
      jsonEncode(dayEntries.map((e) => e.toJson()).toList()),
    );

    _periodIncomeTotal = _calculateIncomeTotalForPeriod();
    notifyListeners();
  }

  /// get total for specific date
  double getSpendingForDate(DateTime date) {
    final key = _dateKey(date);
    return _dailySpendings[key] ?? 0.0;
  }

  /// get entries for a specific date
  List<SpendingEntry> getEntriesForDate(DateTime date) {
    final key = _dateKey(date);
    return _dailyEntries[key] ?? const [];
  }

  List<DateTime> getRecordedSpendingDates({DateTime? start, DateTime? end}) {
    final dates = <DateTime>[];
    for (final dateKey in _dailyEntries.keys) {
      final parsed = _tryParseDateKey(dateKey);
      if (parsed == null) continue;
      if (start != null && _isBefore(parsed, start)) continue;
      if (end != null && _isAfter(parsed, end)) continue;
      dates.add(parsed);
    }
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }

  // --------------------------------------------------
  // INSIGHTS & RECOMMENDATIONS
  // --------------------------------------------------

  /// total per category for the current period
  Map<String, double> getCategoryTotalsForPeriod() {
    final Map<String, double> totals = {};
    if (_periodStart == null || _periodEnd == null) return totals;

    _dailyEntries.forEach((dateStr, entries) {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final d = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        if (!_isBefore(d, _periodStart!) && !_isAfter(d, _periodEnd!)) {
          for (final e in entries) {
            final cat = categoryLabelOf(e);
            totals[cat] = (totals[cat] ?? 0) + e.amount;
          }
        }
      }
    });
    return totals;
  }

  Map<String, int> getCategoryUsageCountsForPeriod() {
    final Map<String, int> counts = {};
    if (_periodStart == null || _periodEnd == null) return counts;

    _dailyEntries.forEach((dateStr, entries) {
      final date = _tryParseDateKey(dateStr);
      if (date == null) return;
      if (_isBefore(date, _periodStart!) || _isAfter(date, _periodEnd!)) {
        return;
      }

      for (final entry in entries) {
        final category = categoryLabelOf(entry);
        counts[category] = (counts[category] ?? 0) + 1;
      }
    });

    return counts;
  }

  List<CategorySpendingRecord> getCategoryRecords(
    String category, {
    bool sortDescending = true,
  }) {
    final normalized = category.trim().toLowerCase();
    final records = <CategorySpendingRecord>[];

    if (_periodStart == null || _periodEnd == null) {
      return records;
    }

    final start = _dateOnly(_periodStart!);
    final end = _dateOnly(_periodEnd!);

    _dailyEntries.forEach((dateKey, entries) {
      final date = _tryParseDateKey(dateKey);
      if (date == null) return;

      final dateOnly = _dateOnly(date);

      if (dateOnly.isBefore(start) || dateOnly.isAfter(end)) {
        return;
      }

      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];

        if (categoryLabelOf(entry).toLowerCase() != normalized) {
          continue;
        }

        records.add(
          CategorySpendingRecord(date: dateOnly, index: i, entry: entry),
        );
      }
    });

    records.sort((a, b) {
      final byDate = sortDescending
          ? b.date.compareTo(a.date)
          : a.date.compareTo(b.date);

      if (byDate != 0) return byDate;

      return sortDescending
          ? b.index.compareTo(a.index)
          : a.index.compareTo(b.index);
    });

    return records;
  }

  /// average per day in period
  double getAveragePerDayInPeriod() {
    if (_periodStart == null || _periodEnd == null) return 0;
    final days = _periodEnd!.difference(_periodStart!).inDays + 1;
    if (days <= 0) return 0;
    return _periodTotal / days;
  }

  /// days where user spent more than dailyAllowance
  List<DateTime> getOverSpendDaysInPeriod() {
    final List<DateTime> days = [];
    if (_periodStart == null || _periodEnd == null) return days;
    _dailySpendings.forEach((dateStr, amount) {
      final d = _tryParseDateKey(dateStr);
      if (d == null) return;
      if (_isBefore(d, _periodStart!) || _isAfter(d, _periodEnd!)) return;
      final allowance = getDailyAllowanceForDate(d);
      if (allowance > 0 && amount > allowance) {
        days.add(d);
      }
    });
    return days;
  }

  /// daily totals (date -> amount) for current period, sorted
  List<MapEntry<DateTime, double>> getDailyTotalsForPeriod() {
    final List<MapEntry<DateTime, double>> result = [];
    if (_periodStart == null || _periodEnd == null) return result;

    _dailySpendings.forEach((dateStr, amount) {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final d = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        if (!_isBefore(d, _periodStart!) && !_isAfter(d, _periodEnd!)) {
          result.add(MapEntry(d, amount));
        }
      }
    });

    result.sort((a, b) => a.key.compareTo(b.key));
    return result;
  }

  /// suggestions based on current data
  List<String> getSmartRecommendations() {
    final List<String> recs = [];

    if (_monthlyBudget > 0) {
      final ratio = _periodTotal / _monthlyBudget;
      if (ratio >= 0.9 && ratio < 1.0) {
        recs.add(
          "You are close to this period's budget. Consider lowering variable expenses.",
        );
      } else if (ratio >= 1.0) {
        recs.add(
          "You exceeded your budget. Next period, increase the budget or reduce daily spending.",
        );
      }
    }

    final catTotals = getCategoryTotalsForPeriod();
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sortedCats.isNotEmpty) {
      final top = sortedCats.first;
      recs.add(
        "Your highest spending is on '${top.key}'. You can set a sub-budget for this category.",
      );
    }

    final overspends = getOverSpendDaysInPeriod();
    if (overspends.length >= 2) {
      recs.add(
        "You overspent on ${overspends.length} days. Try to spread big purchases across days.",
      );
    }

    final avg = getAveragePerDayInPeriod();
    if (dailyAllowance > 0 && avg > dailyAllowance) {
      recs.add(
        "Your average per day (${avg.toStringAsFixed(2)}) is higher than your daily target (${dailyAllowance.toStringAsFixed(2)}).",
      );
    }

    if (recs.isEmpty) {
      recs.add("You're on track 👍 Keep recording your spending.");
    }

    return recs;
  }

  /// send daily summary notification (manual trigger)
  Future<void> sendDailySummaryNotification() async {
    if (!_notificationPreferences.dailySummaryEnabled) return;
    await NotificationService.showDailySummaryNotification(
      periodTotal: _periodTotal,
      budget: _monthlyBudget,
      todayTotal: _todayTotal,
      bankBalanceTotal: _bankAccounts.isEmpty ? null : totalBankBalance,
      includeBudgetContext: _notificationPreferences.includeBudgetContext,
      includeBankContext: _notificationPreferences.includeBankContext,
    );
  }

  // --------------------------------------------------
  // FORECAST (predictive spending)
  // --------------------------------------------------
  double getProjectedPeriodTotal() {
    if (_periodStart == null || _periodEnd == null) return _periodTotal;

    final now = DateTime.now();
    final todayDateOnly = DateTime(now.year, now.month, now.day);
    final start = _periodStart!;
    final end = _periodEnd!;

    final periodStartDateOnly = DateTime(start.year, start.month, start.day);
    final periodEndDateOnly = DateTime(end.year, end.month, end.day);

    // if today is before period, nothing to forecast yet
    if (todayDateOnly.isBefore(periodStartDateOnly)) {
      return _periodTotal;
    }

    // determine the last day to consider as "so far"
    final lastSoFar = todayDateOnly.isAfter(periodEndDateOnly)
        ? periodEndDateOnly
        : todayDateOnly;

    // total days in full period
    final totalDays =
        periodEndDateOnly.difference(periodStartDateOnly).inDays + 1;

    // days elapsed so far in period
    final elapsedDays = lastSoFar.difference(periodStartDateOnly).inDays + 1;

    if (elapsedDays <= 0) return _periodTotal;

    // sum spending only up to lastSoFar
    double spentSoFar = 0;
    _dailySpendings.forEach((dateStr, amount) {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final d = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final dOnly = DateTime(d.year, d.month, d.day);
        if (!dOnly.isBefore(periodStartDateOnly) && !dOnly.isAfter(lastSoFar)) {
          spentSoFar += amount;
        }
      }
    });

    final dailyAvgSoFar = spentSoFar / elapsedDays;
    return dailyAvgSoFar * totalDays;
  }

  int getDaysLeftInPeriod() {
    return getRemainingDaysInPeriod(DateTime.now(), includeCurrentDay: false);
  }

  int getRemainingDaysInPeriod(DateTime date, {bool includeCurrentDay = true}) {
    if (_periodStart == null || _periodEnd == null) return 0;

    final dateOnly = _dateOnly(date);
    final start = _dateOnly(_periodStart!);
    final end = _dateOnly(_periodEnd!);

    if (dateOnly.isAfter(end)) return 0;

    final effectiveStart = dateOnly.isBefore(start) ? start : dateOnly;
    final remaining = end.difference(effectiveStart).inDays;
    return includeCurrentDay ? remaining + 1 : remaining;
  }

  double getRemainingBudgetForDate(DateTime date) {
    if (_monthlyBudget <= 0 || _periodStart == null || _periodEnd == null) {
      return 0;
    }

    final dateOnly = _dateOnly(date);
    final start = _dateOnly(_periodStart!);
    final end = _dateOnly(_periodEnd!);
    if (dateOnly.isAfter(end)) {
      return _monthlyBudget -
          _calculateSpentBeforeDate(end.add(const Duration(days: 1)));
    }

    final effectiveDate = dateOnly.isBefore(start) ? start : dateOnly;
    return _monthlyBudget - _calculateSpentBeforeDate(effectiveDate);
  }

  double getRemainingBudgetIncludingDate(DateTime date) {
    if (_monthlyBudget <= 0 || _periodStart == null || _periodEnd == null) {
      return 0;
    }

    final dateOnly = _dateOnly(date);
    final start = _dateOnly(_periodStart!);
    final end = _dateOnly(_periodEnd!);
    if (dateOnly.isBefore(start)) return _monthlyBudget;

    final effectiveDate = dateOnly.isAfter(end) ? end : dateOnly;
    return _monthlyBudget - getCumulativeSpendingForDate(effectiveDate);
  }

  int getTotalDaysInPeriod() {
    if (_periodStart == null || _periodEnd == null) return 0;

    final start = _dateOnly(_periodStart!);
    final end = _dateOnly(_periodEnd!);
    return end.difference(start).inDays + 1;
  }

  double getBaseDailyBudget() {
    if (_monthlyBudget <= 0) return 0;

    final totalDays = getTotalDaysInPeriod();
    if (totalDays <= 0) return 0;
    return _monthlyBudget / totalDays;
  }

  double getDailyAllowanceForDate(DateTime date) {
    if (_monthlyBudget <= 0 || _periodStart == null || _periodEnd == null) {
      return 0;
    }

    final targetDate = _dateOnly(date);
    final start = _dateOnly(_periodStart!);
    final end = _dateOnly(_periodEnd!);
    if (targetDate.isBefore(start) || targetDate.isAfter(end)) return 0;

    final baseDailyBudget = getBaseDailyBudget();
    if (baseDailyBudget == 0) return 0;

    var allowance = baseDailyBudget;
    var cursor = start;

    while (cursor.isBefore(targetDate)) {
      final spent = getSpendingForDate(cursor);
      allowance = baseDailyBudget + (allowance - spent);
      cursor = cursor.add(const Duration(days: 1));
    }

    return allowance;
  }

  double getRemainingAllowanceForDate(DateTime date) {
    final dateOnly = _dateOnly(date);
    return getDailyAllowanceForDate(dateOnly) - getSpendingForDate(dateOnly);
  }

  double getProjectedAllowanceIfNoMoreSpending(DateTime date, int daysAhead) {
    if (daysAhead < 0) return 0;

    final baseDailyBudget = getBaseDailyBudget();
    if (baseDailyBudget <= 0 || _periodStart == null || _periodEnd == null) {
      return 0;
    }

    final start = _dateOnly(_periodStart!);
    final end = _dateOnly(_periodEnd!);
    final dateOnly = _dateOnly(date);
    if (dateOnly.isBefore(start) || dateOnly.isAfter(end)) return 0;

    var projectedAllowance = getRemainingAllowanceForDate(dateOnly);
    for (var i = 0; i < daysAhead; i++) {
      projectedAllowance += baseDailyBudget;
    }
    return projectedAllowance;
  }

  BudgetGuidanceSnapshot getBudgetGuidanceSnapshotForDate(DateTime date) {
    final dateOnly = _dateOnly(date);
    final baseDailyBudget = getBaseDailyBudget();
    final dailyAllowance = getDailyAllowanceForDate(dateOnly);
    final spentToday = getSpendingForDate(dateOnly);
    final remainingTodayAllowance = dailyAllowance - spentToday;
    final remainingBudget = getRemainingBudgetIncludingDate(dateOnly);
    final remainingDays = getRemainingDaysInPeriod(dateOnly);
    final recurringCommitments = getUpcomingRecurringCommitmentsForPeriod(
      from: dateOnly,
    );
    final upcomingRecurringTotal = recurringCommitments.fold(
      0.0,
      (sum, payment) => sum + payment.amount,
    );
    final discretionaryRemaining = remainingBudget - upcomingRecurringTotal;
    final safeToSpendToday = remainingTodayAllowance <= discretionaryRemaining
        ? remainingTodayAllowance
        : discretionaryRemaining;
    final safeToSpendUntilEndOfPeriod = discretionaryRemaining;

    int? recoveryDays;
    var projectedAllowanceAfterRecovery = remainingTodayAllowance;
    if (baseDailyBudget > 0 && remainingDays > 0) {
      if (remainingTodayAllowance > 0) {
        recoveryDays = 0;
      } else {
        var days = 0;
        while (projectedAllowanceAfterRecovery <= 0 && days < remainingDays) {
          projectedAllowanceAfterRecovery += baseDailyBudget;
          days++;
        }
        if (projectedAllowanceAfterRecovery > 0) {
          recoveryDays = days;
        } else {
          recoveryDays = null;
        }
      }
    }

    final tomorrowAllowanceIfNoMoreSpending =
        getProjectedAllowanceIfNoMoreSpending(dateOnly, 1);
    final followingDayAllowanceIfNoSpendingTomorrow =
        getProjectedAllowanceIfNoMoreSpending(dateOnly, 2);
    final double recommendedDailyCap = remainingDays > 0
        ? discretionaryRemaining / remainingDays
        : 0.0;
    final double normalizedDailyCap = recommendedDailyCap < 0
        ? 0.0
        : recommendedDailyCap;
    final double dailyReductionNeeded = baseDailyBudget > normalizedDailyCap
        ? baseDailyBudget - normalizedDailyCap
        : 0.0;

    return BudgetGuidanceSnapshot(
      date: dateOnly,
      baseDailyBudget: baseDailyBudget,
      dailyAllowance: dailyAllowance,
      spentToday: spentToday,
      remainingTodayAllowance: remainingTodayAllowance,
      remainingBudget: remainingBudget,
      remainingDays: remainingDays,
      upcomingRecurringTotal: upcomingRecurringTotal,
      upcomingRecurringPayments: recurringCommitments,
      discretionaryRemaining: discretionaryRemaining,
      safeToSpendToday: safeToSpendToday < 0 ? 0.0 : safeToSpendToday,
      safeToSpendUntilEndOfPeriod: safeToSpendUntilEndOfPeriod,
      recoveryDays: recoveryDays,
      projectedAllowanceAfterRecovery: projectedAllowanceAfterRecovery > 0
          ? projectedAllowanceAfterRecovery
          : 0.0,
      tomorrowAllowanceIfNoMoreSpending: tomorrowAllowanceIfNoMoreSpending < 0
          ? 0.0
          : tomorrowAllowanceIfNoMoreSpending,
      followingDayAllowanceIfNoSpendingTomorrow:
          followingDayAllowanceIfNoSpendingTomorrow < 0
          ? 0.0
          : followingDayAllowanceIfNoSpendingTomorrow,
      recommendedDailyCap: normalizedDailyCap,
      dailyReductionNeeded: dailyReductionNeeded,
    );
  }

  DailyBudgetAdjustment? getDailyBudgetAdjustmentForDate(DateTime date) {
    if (_monthlyBudget <= 0 || _periodStart == null || _periodEnd == null) {
      return null;
    }

    final dateOnly = _dateOnly(date);
    final previousDate = dateOnly.subtract(const Duration(days: 1));
    final start = _dateOnly(_periodStart!);
    final end = _dateOnly(_periodEnd!);

    if (dateOnly.isBefore(start) || dateOnly.isAfter(end)) return null;
    if (!previousDate.isBefore(start)) {
      return DailyBudgetAdjustment(
        date: dateOnly,
        previousDate: previousDate,
        previousAllowance: getDailyAllowanceForDate(previousDate),
        previousSpent: getSpendingForDate(previousDate),
        currentAllowance: getDailyAllowanceForDate(dateOnly),
        cumulativeBudget: getCumulativeBudgetForDate(previousDate),
        cumulativeSpent: getCumulativeSpendingForDate(previousDate),
        baseDailyBudget: getBaseDailyBudget(),
        remainingBudget: getRemainingBudgetForDate(dateOnly),
        remainingDays: getRemainingDaysInPeriod(dateOnly),
      );
    }

    return null;
  }

  List<String> getForecastMessages() {
    final List<String> msgs = [];

    if (_periodStart == null || _periodEnd == null) {
      return msgs;
    }

    final projected = getProjectedPeriodTotal();
    final daysLeft = getDaysLeftInPeriod();

    if (daysLeft > 0) {
      msgs.add(
        "If you continue like this, you’ll spend about ${projected.toStringAsFixed(2)} SAR by the end of this period.",
      );
    } else {
      msgs.add(
        "This period is almost over. Total spending settled around ${_periodTotal.toStringAsFixed(2)} SAR.",
      );
    }

    if (_monthlyBudget > 0) {
      final diff = projected - _monthlyBudget;
      if (diff > 0) {
        msgs.add(
          "At your current rate, you may exceed your budget by ${diff.toStringAsFixed(2)} SAR.",
        );
      } else {
        msgs.add(
          "Good job! You’re on track to stay within your budget with around ${(-diff).toStringAsFixed(2)} SAR to spare.",
        );
      }
    }

    final cats = getCategoryTotalsForPeriod();
    if (cats.isNotEmpty) {
      final top = cats.entries.reduce((a, b) => a.value >= b.value ? a : b);
      msgs.add("Your highest spending category so far is '${top.key}'.");
    }

    return msgs;
  }

  // --------------------------------------------------
  // helpers
  // --------------------------------------------------
  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _bankNameKey(String? value) => (value ?? '').trim().toLowerCase();

  List<BankAccount> _normalizeBankAccounts(Iterable<BankAccount> accounts) {
    final result = <BankAccount>[];
    final seenNames = <String>{};

    for (final account in accounts) {
      final name = account.name.trim();
      final key = _bankNameKey(name);
      if (name.isEmpty || seenNames.contains(key)) continue;

      final id = account.id.trim().isEmpty ? BankAccount.newId() : account.id;
      final balance = account.balance.isFinite ? account.balance : 0.0;
      result.add(BankAccount(id: id, name: name, balance: balance));
      seenNames.add(key);
    }

    return result;
  }

  int _findBankAccountIndex({String? bankAccountId, String? bankName}) {
    final id = bankAccountId?.trim();
    if (id != null && id.isNotEmpty) {
      for (var i = 0; i < _bankAccounts.length; i++) {
        if (_bankAccounts[i].id == id) return i;
      }
    }

    final nameKey = _bankNameKey(bankName);
    if (nameKey.isEmpty) return -1;
    for (var i = 0; i < _bankAccounts.length; i++) {
      if (_bankNameKey(_bankAccounts[i].name) == nameKey) return i;
    }
    return -1;
  }

  bool _syncBankBalancesForEntryChange({
    required List<SpendingEntry> previousEntries,
    required List<SpendingEntry> nextEntries,
  }) {
    final deltas = <String, double>{};

    void addDelta(SpendingEntry entry, double delta) {
      if (entry.bankAccountId == null || entry.bankAccountId!.trim().isEmpty) {
        return;
      }
      final index = _findBankAccountIndex(
        bankAccountId: entry.bankAccountId,
        bankName: entry.bank,
      );
      if (index == -1 || delta == 0) return;
      final id = _bankAccounts[index].id;
      deltas[id] = (deltas[id] ?? 0) + delta;
    }

    for (final entry in previousEntries) {
      addDelta(entry, entry.amount);
    }
    for (final entry in nextEntries) {
      addDelta(entry, -entry.amount);
    }

    var changed = false;
    for (final delta in deltas.entries) {
      if (delta.value == 0) continue;
      final index = _findBankAccountIndex(bankAccountId: delta.key);
      if (index == -1) continue;
      final account = _bankAccounts[index];
      _bankAccounts[index] = account.copyWith(
        balance: account.balance + delta.value,
      );
      changed = true;
    }

    return changed;
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _calculateSpentBeforeDate(DateTime date) {
    if (_periodStart == null || _periodEnd == null) return 0;

    final start = _dateOnly(_periodStart!);
    final end = _dateOnly(_periodEnd!);
    final cutoff = _dateOnly(date);
    double total = 0;

    _dailySpendings.forEach((dateStr, amount) {
      final parsed = _tryParseDateKey(dateStr);
      if (parsed == null) return;
      final day = _dateOnly(parsed);
      if (day.isBefore(start) || day.isAfter(end) || !day.isBefore(cutoff)) {
        return;
      }
      total += amount;
    });

    return total;
  }

  double getCumulativeSpendingForDate(DateTime date) {
    final dateOnly = _dateOnly(date);
    return _calculateSpentBeforeDate(dateOnly.add(const Duration(days: 1)));
  }

  double getCumulativeBudgetForDate(DateTime date) {
    if (_monthlyBudget <= 0 || _periodStart == null || _periodEnd == null) {
      return 0;
    }

    final dateOnly = _dateOnly(date);
    final start = _dateOnly(_periodStart!);
    final end = _dateOnly(_periodEnd!);
    if (dateOnly.isBefore(start)) return 0;

    final effectiveEnd = dateOnly.isAfter(end) ? end : dateOnly;
    final elapsedDays = effectiveEnd.difference(start).inDays + 1;
    if (elapsedDays <= 0) return 0;

    return getBaseDailyBudget() * elapsedDays;
  }

  DateTime? _tryParseDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  double _calculateTotalForPeriod() {
    if (_periodStart == null || _periodEnd == null) {
      return 0;
    }
    double total = 0;
    _dailySpendings.forEach((dateStr, amount) {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          final d = DateTime(year, month, day);
          if (!_isBefore(d, _periodStart!) && !_isAfter(d, _periodEnd!)) {
            total += amount;
          }
        }
      }
    });
    return total;
  }

  double _calculateIncomeTotalForPeriod() {
    if (_periodStart == null || _periodEnd == null) return 0;
    double total = 0;

    _incomeByDate.forEach((dateStr, entries) {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          final d = DateTime(year, month, day);
          if (!_isBefore(d, _periodStart!) && !_isAfter(d, _periodEnd!)) {
            total += entries.fold(0.0, (sum, e) => sum + e.amount);
          }
        }
      }
    });

    return total;
  }

  bool _isBefore(DateTime a, DateTime b) =>
      a.isBefore(DateTime(b.year, b.month, b.day));

  bool _isAfter(DateTime a, DateTime b) =>
      a.isAfter(DateTime(b.year, b.month, b.day, 23, 59, 59));

  // ---------- local save helpers ----------
  NotificationPreferences _loadNotificationPreferencesLocal(
    SharedPreferences prefs,
    String uid,
  ) {
    final raw = prefs.getString(_p(uid, 'notificationPreferences'));
    if (raw == null || raw.isEmpty) return const NotificationPreferences();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return NotificationPreferences.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      // ignore corrupt data
    }

    return const NotificationPreferences();
  }

  Future<void> _saveMetaLocal() async {
    final prefs = await SharedPreferences.getInstance();
    if (_userId == null) return;
    final uid = _userId!;
    await prefs.setDouble(_p(uid, 'monthlyBudget'), _monthlyBudget);
    await prefs.setString(
      _p(uid, 'notificationPreferences'),
      jsonEncode(_notificationPreferences.toJson()),
    );
    await _saveBankAccountsLocal(prefs);

    if (_periodStart != null) {
      await prefs.setString(
        _p(uid, 'period_start'),
        _periodStart!.toIso8601String(),
      );
    }
    if (_periodEnd != null) {
      await prefs.setString(
        _p(uid, 'period_end'),
        _periodEnd!.toIso8601String(),
      );
    }
  }

  Future<void> _saveAllLocal() async {
    // Must be user-scoped, otherwise accounts will mix.
    if (_userId == null) return;
    final uid = _userId!;

    final prefs = await SharedPreferences.getInstance();
    await _saveMetaLocal();

    // save all spending days
    for (final entry in _dailyEntries.entries) {
      final dateKey = entry.key;
      final dayEntries = entry.value;
      final total = dayEntries.fold(0.0, (s, e) => s + e.amount);

      await prefs.setDouble(_p(uid, 'spend_$dateKey'), total);
      await prefs.setString(
        _p(uid, 'spendEntries_$dateKey'),
        jsonEncode(dayEntries.map((e) => e.toJson()).toList()),
      );
    }

    // save all income days
    for (final entry in _incomeByDate.entries) {
      final dateKey = entry.key;
      final dayEntries = entry.value;
      final total = dayEntries.fold(0.0, (s, e) => s + e.amount);

      await prefs.setDouble(_p(uid, 'income_$dateKey'), total);
      await prefs.setString(
        _p(uid, 'incomeEntries_$dateKey'),
        jsonEncode(dayEntries.map((e) => e.toJson()).toList()),
      );
    }

    // save recurring
    await _saveRecurringLocal(prefs);
  }

  Future<void> _saveRecurringLocal(SharedPreferences prefs) async {
    if (_userId == null) return;
    final uid = _userId!;
    await prefs.setString(
      _p(uid, 'recurringPayments'),
      jsonEncode(_recurringPayments.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveBankAccountsLocal([SharedPreferences? prefs]) async {
    if (_userId == null) return;
    final uid = _userId!;
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    await resolvedPrefs.setString(
      _p(uid, 'bankAccounts'),
      jsonEncode(_bankAccounts.map((e) => e.toJson()).toList()),
    );
  }

  // ---------- remote save helpers ----------
  Future<void> _saveMetaRemote() async {
    if (_userId == null) return;
    await FirestoreService.instance.saveUserMeta(
      uid: _userId!,
      monthlyBudget: _monthlyBudget,
      periodStart: _periodStart,
      periodEnd: _periodEnd,
      bankAccounts: _bankAccounts.map((e) => e.toJson()).toList(),
      notificationPreferences: _notificationPreferences.toJson(),
      recurringPayments: _recurringPayments.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> _saveBankAccountsRemote() async {
    await _saveMetaRemote();
  }

  Future<void> _saveDayRemote(String dateKey) async {
    if (_userId == null) return;
    final entries = _dailyEntries[dateKey] ?? const <SpendingEntry>[];
    final total = entries.fold(0.0, (s, e) => s + e.amount);
    await FirestoreService.instance.saveDay(
      uid: _userId!,
      dateKey: dateKey,
      total: total,
      entries: entries.map((e) => e.toJson()).toList(),
    );
  }
}
