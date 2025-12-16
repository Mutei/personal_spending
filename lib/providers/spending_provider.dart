import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';

/// A single spending entry for a specific date
class SpendingEntry {
  final double amount; // already multiplied if qty was given
  final String? item;
  final String? bank;
  final int? qty;
  final String? category; // for analytics

  SpendingEntry({
    required this.amount,
    this.item,
    this.bank,
    this.qty,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'item': item,
    'bank': bank,
    'qty': qty,
    'category': category,
  };

  factory SpendingEntry.fromJson(Map<String, dynamic> json) => SpendingEntry(
    amount: (json['amount'] ?? 0).toDouble(),
    item: json['item'] as String?,
    bank: json['bank'] as String?,
    qty: json['qty'] != null ? (json['qty'] as num).toInt() : null,
    category: json['category'] as String?,
  );
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

/// Monthly recurring payments like rent, gym, subscriptions
class RecurringPayment {
  final String id; // local id
  final String title;
  final double amount;
  final int dayOfMonth; // 1..31
  final String? category;
  final String? bank;
  final bool autoAdd; // if true, auto-add spending on due day

  RecurringPayment({
    required this.id,
    required this.title,
    required this.amount,
    required this.dayOfMonth,
    this.category,
    this.bank,
    this.autoAdd = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'dayOfMonth': dayOfMonth,
    'category': category,
    'bank': bank,
    'autoAdd': autoAdd,
  };

  factory RecurringPayment.fromJson(Map<String, dynamic> json) =>
      RecurringPayment(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] ?? 0).toDouble(),
        dayOfMonth: (json['dayOfMonth'] as num).toInt(),
        category: json['category'] as String?,
        bank: json['bank'] as String?,
        autoAdd: (json['autoAdd'] as bool?) ?? false,
      );
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

  // simple daily allowance
  double get dailyAllowance => _monthlyBudget > 0 ? _monthlyBudget / 30 : 0;

  // --------------------------------------------------
  // load all LOCAL data
  // --------------------------------------------------
  Future<void> loadData(String uid) async {
    _userId = uid; // ✅ important
    final prefs = await SharedPreferences.getInstance();

    _monthlyBudget = prefs.getDouble(_p(uid, 'monthlyBudget')) ?? 0;

    _dailySpendings.clear();
    _dailyEntries.clear();
    _incomeByDate.clear();
    _recurringPayments.clear();
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
              qty: entry.qty,
              category: _canonicalizeCategory(entry.category),
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
              category: _canonicalizeCategory(rp.category),
              bank: rp.bank,
              autoAdd: rp.autoAdd,
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
    // Only clear when switching between two real users
    if (_userId != null && uid != null && _userId != uid) {
      _dailySpendings.clear();
      _dailyEntries.clear();
      _incomeByDate.clear();
      _recurringPayments.clear();
      _categoryCanon.clear();
      _todayTotal = 0;
      _periodTotal = 0;
      _periodIncomeTotal = 0;
      _remoteLoaded = false;
    }

    if (uid == null) {
      _userId = null;
      _remoteLoaded = false;
      return;
    }

    if (_userId == uid && _remoteLoaded) {
      return;
    }

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
            qty: entry.qty,
            category: _canonicalizeCategory(entry.category),
          );
        }).toList();

        _dailyEntries[dateKey] = entries;

        final total =
            (data['total'] as num?)?.toDouble() ??
            entries.fold(0.0, (sum, e) => sum! + e.amount);

        _dailySpendings[dateKey] = total!;
      }

      _periodTotal = _calculateTotalForPeriod();
      _periodIncomeTotal = _calculateIncomeTotalForPeriod();

      _remoteLoaded = true;

      // save user-scoped local cache
      await _saveAllLocal();

      notifyListeners();
    } catch (_) {
      // ignore: if rules forbid or offline, we just keep local
    }
  }

  // --------------------------------------------------
  // set monthly budget
  // --------------------------------------------------
  Future<void> setMonthlyBudget(double value) async {
    _monthlyBudget = value;
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
    int? qty,
    String? category,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _dateKey(date);

    // multiply by quantity if provided
    final double totalAmount = (qty != null && qty > 0)
        ? (amount * qty)
        : amount;

    final normalizedCategory = _canonicalizeCategory(category);

    if (replace) {
      _dailyEntries[dateKey] = [
        SpendingEntry(
          amount: totalAmount,
          item: item,
          bank: bank,
          qty: qty,
          category: normalizedCategory,
        ),
      ];
    } else {
      final current = List<SpendingEntry>.from(
        _dailyEntries[dateKey] ?? const <SpendingEntry>[],
      );
      current.add(
        SpendingEntry(
          amount: totalAmount,
          item: item,
          bank: bank,
          qty: qty,
          category: normalizedCategory,
        ),
      );
      _dailyEntries[dateKey] = current;
    }

    await _recalcAndPersistDay(dateKey, prefs);
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

  // --------------------------------------------------
  // RECURRING PAYMENTS METHODS
  // --------------------------------------------------
  Future<void> addRecurringPayment({
    required String title,
    required double amount,
    required int dayOfMonth,
    String? category,
    String? bank,
    bool autoAdd = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final normalizedCategory = _canonicalizeCategory(category);

    _recurringPayments.add(
      RecurringPayment(
        id: id,
        title: title,
        amount: amount,
        dayOfMonth: dayOfMonth,
        category: normalizedCategory,
        bank: bank,
        autoAdd: autoAdd,
      ),
    );

    await _saveRecurringLocal(prefs);
    notifyListeners();
  }

  Future<void> removeRecurringPayment(String id) async {
    final prefs = await SharedPreferences.getInstance();
    _recurringPayments.removeWhere((p) => p.id == id);
    await _saveRecurringLocal(prefs);
    notifyListeners();
  }

  /// Next due date for a given recurring payment (this month or next)
  DateTime getNextDueDate(RecurringPayment p) {
    final now = DateTime.now();
    final todayDateOnly = DateTime(now.year, now.month, now.day);

    // clamp dayOfMonth to valid for this month
    final safeDay = p.dayOfMonth.clamp(1, 28); // simple & safe
    DateTime due = DateTime(now.year, now.month, safeDay);

    if (due.isBefore(todayDateOnly)) {
      // next month
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final nmSafeDay = p.dayOfMonth.clamp(1, 28);
      due = DateTime(nextMonth.year, nextMonth.month, nmSafeDay);
    }
    return due;
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

  /// Auto-add recurring payments for today (only once per day)
  Future<void> processRecurringForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dateKey(DateTime.now());
    final lastProcessed = prefs.getString('recurring_last_processed');

    if (lastProcessed == todayKey) {
      // already processed today
      return;
    }

    final now = DateTime.now();
    final todayDay = now.day;

    for (final p in _recurringPayments) {
      if (p.dayOfMonth == todayDay && p.autoAdd) {
        await addSpendingForDate(
          now,
          p.amount,
          item: p.title,
          bank: p.bank,
          category: p.category, // already canonical
        );
      }
    }

    await prefs.setString('recurring_last_processed', todayKey);
  }

  // --------------------------------------------------
  // edit an existing entry (by index)
  // --------------------------------------------------
  Future<void> updateEntryForDate({
    required DateTime date,
    required int index,
    required double amount,
    String? item,
    String? bank,
    int? qty,
    String? category,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _dateKey(date);

    final list = _dailyEntries[dateKey];
    if (list == null || index < 0 || index >= list.length) return;

    final double totalAmount = (qty != null && qty > 0)
        ? (amount * qty)
        : amount;

    final normalizedCategory = _canonicalizeCategory(
      category ?? list[index].category,
    );

    list[index] = SpendingEntry(
      amount: totalAmount,
      item: item,
      bank: bank,
      qty: qty,
      category: normalizedCategory,
    );

    _dailyEntries[dateKey] = List<SpendingEntry>.from(list);
    await _recalcAndPersistDay(dateKey, prefs);
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

    list.removeAt(index);

    if (list.isEmpty) {
      _dailyEntries.remove(dateKey);
      _dailySpendings.remove(dateKey);
      await prefs.remove('spend_$dateKey');
      await prefs.remove('spendEntries_$dateKey');
      // remote: set empty day
      await _saveDayRemote(dateKey);
    } else {
      _dailyEntries[dateKey] = List<SpendingEntry>.from(list);
      await _recalcAndPersistDay(dateKey, prefs);
      await _saveDayRemote(dateKey);
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

    if (dailyAllowance > 0 && newTotal > dailyAllowance) {
      await NotificationService.showOverSpendNotification(
        todayTotal: newTotal,
        allowed: dailyAllowance,
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
            final raw = e.category;
            final cat = (raw == null || raw.trim().isEmpty)
                ? 'Uncategorized'
                : raw.trim();
            totals[cat] = (totals[cat] ?? 0) + e.amount;
          }
        }
      }
    });
    return totals;
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
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final d = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        if (!_isBefore(d, _periodStart!) && !_isAfter(d, _periodEnd!)) {
          if (dailyAllowance > 0 && amount > dailyAllowance) {
            days.add(d);
          }
        }
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
    await NotificationService.showDailySummaryNotification(
      periodTotal: _periodTotal,
      budget: _monthlyBudget,
      todayTotal: _todayTotal,
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
    final elapsedDays =
        lastSoFar.difference(periodStartDateOnly).inDays + 1; // >= 1

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
    if (_periodStart == null || _periodEnd == null) return 0;

    final now = DateTime.now();
    final todayDateOnly = DateTime(now.year, now.month, now.day);
    final end = _periodEnd!;
    final periodEndDateOnly = DateTime(end.year, end.month, end.day);

    if (todayDateOnly.isAfter(periodEndDateOnly)) return 0;
    if (todayDateOnly.isBefore(_periodStart!)) {
      return periodEndDateOnly
              .difference(
                DateTime(
                  _periodStart!.year,
                  _periodStart!.month,
                  _periodStart!.day,
                ),
              )
              .inDays +
          1;
    }

    return periodEndDateOnly.difference(todayDateOnly).inDays;
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
  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
  Future<void> _saveMetaLocal() async {
    final prefs = await SharedPreferences.getInstance();
    if (_userId == null) return;
    final uid = _userId!;
    await prefs.setDouble(_p(uid, 'monthlyBudget'), _monthlyBudget);

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
    await _saveMetaLocal(); // make sure _saveMetaLocal() also uses uid-scoped keys

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
    await _saveRecurringLocal(
      prefs,
    ); // this must also use _p(uid, 'recurringPayments')
  }

  Future<void> _saveRecurringLocal(SharedPreferences prefs) async {
    if (_userId == null) return;
    final uid = _userId!;
    await prefs.setString(
      _p(uid, 'recurringPayments'),
      jsonEncode(_recurringPayments.map((e) => e.toJson()).toList()),
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
    );
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
