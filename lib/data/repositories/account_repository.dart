import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/core/cache/local_cache.dart';
import 'package:swoosh/models/account.dart';

class AccountRepository {
  AccountRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<Account>> fetchAll() async {
    try {
      final data = await _client
          .from('accounts')
          .select()
          .order('created_at', ascending: false);
      final list = (data as List).cast<Map<String, dynamic>>();
      await _cache.saveAccounts(list);
      return list.map(Account.fromJson).toList();
    } catch (_) {
      final cached = _cache.getAccounts();
      if (cached != null) {
        return cached.map(Account.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<Account> create(Account account) async {
    final data = await _client
        .from('accounts')
        .insert(account.toJson())
        .select()
        .single();
    return Account.fromJson(data);
  }

  Future<Account> update(String id, Map<String, dynamic> updates) async {
    final data = await _client
        .from('accounts')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Account.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _client.from('accounts').delete().eq('id', id);
  }
}
