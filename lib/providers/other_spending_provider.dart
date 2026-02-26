import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/firestore_service.dart';

class OtherSpendingEntry {
  final String id; // firestore doc id
  final String dayId; // yyyy-MM-dd
  final DateTime date;
  final double amount;
  final String? title;
  final String? category;
  final String? bank;
  final int? qty;

  OtherSpendingEntry({
    required this.id,
    required this.dayId,
    required this.date,
    required this.amount,
    this.title,
    this.category,
    this.bank,
    this.qty,
  });
}

class OtherSpendingProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _fs = FirestoreService.instance;
  String? _uid;

  final List<OtherSpendingEntry> _entries = [];

  // current filter
  DateTime? _filterStart;
  DateTime? _filterEnd;

  // -------- CATEGORY CANONICALIZATION (Snack/snacks/SNACK etc.) --------
  /// key (normalized, usually singular lowercase) -> canonical label (first form entered)
  final Map<String, String> _categoryCanon = {};

  Future<void> attachUser(String? uid) async {
    if (uid == _uid && _hasLoaded) return;

    // if switching users OR logging out
    _uid = uid;

    _entries.clear();
    _categoryCanon.clear();
    _filterStart = null;
    _filterEnd = null;

    _hasLoaded = false;
    _isLoading = false;

    notifyListeners();

    if (uid == null) return;

    // auto-load for new uid
    await loadDataForUid(uid);
  }

  Future<void> loadDataForUid(String uid) async {
    if (_isLoading) return;
    if (_hasLoaded) return;

    _isLoading = true;

    try {
      _entries.clear();
      _categoryCanon.clear();

      final dayDocs = await _fs.getOtherSpendingDays(uid);

      const int chunkSize = 20;

      for (int i = 0; i < dayDocs.length; i += chunkSize) {
        final chunk = dayDocs.skip(i).take(chunkSize).toList();

        final snaps = await Future.wait(
          chunk.map((day) => day.reference.collection('entries').get()),
        );

        for (int idx = 0; idx < chunk.length; idx++) {
          final dayId = chunk[idx].id;
          final entriesSnap = snaps[idx];

          for (final doc in entriesSnap.docs) {
            final data = doc.data();
            final ts = data['date'] as Timestamp?;
            final date = ts != null ? ts.toDate() : DateTime.now();
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

            final rawCategory = data['category'] as String?;
            final normalizedCategory = _canonicalizeCategory(rawCategory);

            _entries.add(
              OtherSpendingEntry(
                id: doc.id,
                dayId: dayId,
                date: date,
                amount: amount,
                title: data['title'] as String?,
                category: normalizedCategory,
                bank: data['bank'] as String?,
                qty: data['qty'] != null ? (data['qty'] as num).toInt() : null,
              ),
            );
          }
        }

        notifyListeners();
      }

      _entries.sort((a, b) => b.date.compareTo(a.date));
      _hasLoaded = true;
      notifyListeners();
    } finally {
      _isLoading = false;
    }
  }

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
    if (_categoryCanon.containsKey(key)) return _categoryCanon[key];

    // If we know the singular version -> reuse canonical
    if (_categoryCanon.containsKey(singularKey))
      return _categoryCanon[singularKey];

    // New category -> store canonical as first seen spelling
    _categoryCanon[singularKey] = trimmed;
    if (key != singularKey) _categoryCanon[key] = trimmed;

    return trimmed;
  }

  // ------------------------------------------------------------
  // PUBLIC GETTERS
  // ------------------------------------------------------------

  /// Whether initial load already happened
  bool _isLoading = false;
  bool _hasLoaded = false;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  /// Raw filtered entries (may contain duplicates if Firestore has them)
  List<OtherSpendingEntry> get entries {
    final filtered = _applyFilter(_entries);
    final copy = List<OtherSpendingEntry>.from(filtered);
    copy.sort((a, b) => b.date.compareTo(a.date));
    return copy;
  }

  /// Filtered + de-duplicated entries.
  ///
  /// Two entries are considered the same if:
  ///  - title, amount, date, bank, qty, category are the same.
  List<OtherSpendingEntry> get uniqueEntries {
    final filtered = _applyFilter(_entries);
    final Map<String, OtherSpendingEntry> map = {};

    for (final e in filtered) {
      final key =
          '${e.title ?? ''}|${e.amount}|${e.date.toIso8601String()}|${e.bank ?? ''}|${e.qty ?? ''}|${(e.category ?? '').trim()}';
      map[key] = e; // last wins
    }

    final list = map.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Total using **de-duplicated** entries
  double get totalOtherSpending =>
      uniqueEntries.fold(0.0, (sum, e) => sum + e.amount);

  /// Totals per category using **de-duplicated** entries
  Map<String, double> get categoryTotals {
    final Map<String, double> result = {};
    for (final e in uniqueEntries) {
      final raw = e.category;
      final cat = (raw == null || raw.trim().isEmpty)
          ? 'Uncategorized'
          : raw.trim();
      result[cat] = (result[cat] ?? 0) + e.amount;
    }
    return result;
  }

  bool get hasCustomFilter => _filterStart != null && _filterEnd != null;

  // ------------------------------------------------------------
  // LOAD FROM FIRESTORE (FAST + SMOOTH)
  // ------------------------------------------------------------
  Future<void> loadData() async {
    final uid = _uid ?? _auth.currentUser?.uid;
    if (uid == null) return;
    await loadDataForUid(uid);
  }

  /// Force reload from Firestore (useful for pull-to-refresh)
  Future<void> refresh({bool clearFilter = false}) async {
    if (clearFilter) {
      _filterStart = null;
      _filterEnd = null;
    }
    _hasLoaded = false;
    _entries.clear();
    notifyListeners();

    final uid = _uid ?? _auth.currentUser?.uid;
    if (uid == null) return;

    await loadDataForUid(uid);
  }

  // ------------------------------------------------------------
  // ADD
  // ------------------------------------------------------------
  Future<void> addEntry({
    required DateTime date,
    required double amount,
    String? title,
    String? category,
    String? bank,
    int? qty,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final double finalAmount = (qty != null && qty > 0)
        ? (amount * qty)
        : amount;

    final normalizedCategory = _canonicalizeCategory(category);

    final entryId = await _fs.addOtherSpending(
      uid: uid,
      date: date,
      amount: finalAmount,
      title: title,
      category: normalizedCategory,
      bank: bank,
      qty: qty,
    );

    final dayId = _fs.buildDateKey(date);

    _entries.add(
      OtherSpendingEntry(
        id: entryId,
        dayId: dayId,
        date: date,
        amount: finalAmount,
        title: title,
        category: normalizedCategory,
        bank: bank,
        qty: qty,
      ),
    );

    _entries.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  // ------------------------------------------------------------
  // UPDATE
  // ------------------------------------------------------------
  Future<void> updateEntry(
    OtherSpendingEntry entry, {
    required DateTime date,
    required double amount,
    String? title,
    String? category,
    String? bank,
    int? qty,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final double finalAmount = (qty != null && qty > 0)
        ? (amount * qty)
        : amount;

    final newDayId = _fs.buildDateKey(date);
    final normalizedCategory = _canonicalizeCategory(
      category ?? entry.category,
    );

    await _fs.updateOtherSpending(
      uid: uid,
      dayId: entry.dayId,
      entryId: entry.id,
      data: {
        'date': Timestamp.fromDate(date),
        'amount': finalAmount,
        'title': title,
        'category': normalizedCategory,
        'bank': bank,
        'qty': qty,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    final idx = _entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      _entries[idx] = OtherSpendingEntry(
        id: entry.id,
        dayId: newDayId,
        date: date,
        amount: finalAmount,
        title: title,
        category: normalizedCategory,
        bank: bank,
        qty: qty,
      );
      _entries.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    }
  }

  // ------------------------------------------------------------
  // DELETE
  // ------------------------------------------------------------
  Future<void> removeEntry(OtherSpendingEntry entry) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _fs.deleteOtherSpending(
      uid: uid,
      dayId: entry.dayId,
      entryId: entry.id,
    );

    _entries.removeWhere((e) => e.id == entry.id);
    notifyListeners();
  }

  /// Delete ALL entries belonging to a specific (display) category
  Future<void> removeCategory(String categoryName) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final toDelete = _entries.where((e) {
      final raw = e.category;
      final cat = (raw == null || raw.trim().isEmpty)
          ? 'Uncategorized'
          : raw.trim();
      return cat == categoryName;
    }).toList();

    for (final entry in toDelete) {
      await _fs.deleteOtherSpending(
        uid: uid,
        dayId: entry.dayId,
        entryId: entry.id,
      );
      _entries.removeWhere((e) => e.id == entry.id);
    }

    notifyListeners();
  }

  // ------------------------------------------------------------
  // FILTERS
  // ------------------------------------------------------------
  void clearFilter() {
    _filterStart = null;
    _filterEnd = null;
    notifyListeners();
  }

  void filterThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    _filterStart = start;
    _filterEnd = end;
    notifyListeners();
  }

  void setCustomFilter(DateTime start, DateTime end) {
    if (start.isAfter(end)) {
      final tmp = start;
      start = end;
      end = tmp;
    }
    _filterStart = DateTime(start.year, start.month, start.day);
    _filterEnd = DateTime(end.year, end.month, end.day);
    notifyListeners();
  }

  List<OtherSpendingEntry> _applyFilter(List<OtherSpendingEntry> source) {
    if (_filterStart == null || _filterEnd == null) return source;

    return source.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      return !d.isBefore(_filterStart!) && !d.isAfter(_filterEnd!);
    }).toList();
  }
}
