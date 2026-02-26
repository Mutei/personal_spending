import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_account.dart';

class AccountStore {
  static const _listKey = "saved_accounts_v1";
  static const _pwdPrefix = "pwd_"; // pwd_<uid>

  final _secure = const FlutterSecureStorage();

  Future<List<SavedAccount>> getAccounts() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_listKey);
    if (raw == null || raw.isEmpty) return [];
    final List list = jsonDecode(raw);
    final accs = list
        .map((e) => SavedAccount.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    accs.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return accs;
  }

  Future<void> upsertAccount(SavedAccount account, {String? password}) async {
    final sp = await SharedPreferences.getInstance();
    final accs = await getAccounts();

    final idx = accs.indexWhere((a) => a.uid == account.uid);
    final updated = account.copyWith(lastUsed: DateTime.now());

    if (idx >= 0) {
      accs[idx] = updated;
    } else {
      accs.add(updated);
    }

    // keep most recent first
    accs.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));

    await sp.setString(
      _listKey,
      jsonEncode(accs.map((e) => e.toMap()).toList()),
    );

    if (password != null && password.isNotEmpty) {
      await _secure.write(key: "$_pwdPrefix${account.uid}", value: password);
    }
  }

  Future<void> removeAccount(String uid) async {
    final sp = await SharedPreferences.getInstance();
    final accs = await getAccounts();
    accs.removeWhere((a) => a.uid == uid);
    await sp.setString(
      _listKey,
      jsonEncode(accs.map((e) => e.toMap()).toList()),
    );
    await _secure.delete(key: "$_pwdPrefix$uid");
  }

  Future<String?> getPassword(String uid) async {
    return _secure.read(key: "$_pwdPrefix$uid");
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_listKey);
    // (optional) you can also delete all secure keys, but that needs key listing support.
  }
}
