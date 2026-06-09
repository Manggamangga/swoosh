import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  LocalCache(this._prefs);

  final SharedPreferences _prefs;

  static const _accountsKey = 'cache_accounts';
  static const _transactionsKey = 'cache_transactions';
  static const _lastSyncKey = 'cache_last_sync';

  Future<void> saveAccounts(List<Map<String, dynamic>> data) async {
    await _prefs.setString(_accountsKey, jsonEncode(data));
    await _touchSync();
  }

  Future<void> saveTransactions(List<Map<String, dynamic>> data) async {
    await _prefs.setString(_transactionsKey, jsonEncode(data));
    await _touchSync();
  }

  List<Map<String, dynamic>>? getAccounts() {
    final raw = _prefs.getString(_accountsKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>>? getTransactions() {
    final raw = _prefs.getString(_transactionsKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  DateTime? get lastSync {
    final raw = _prefs.getString(_lastSyncKey);
    return raw != null ? DateTime.parse(raw) : null;
  }

  Future<void> clear() async {
    await _prefs.remove(_accountsKey);
    await _prefs.remove(_transactionsKey);
    await _prefs.remove(_lastSyncKey);
  }

  Future<void> _touchSync() async {
    await _prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }
}
