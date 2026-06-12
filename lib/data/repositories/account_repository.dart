import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/core/cache/local_cache.dart';
import 'package:swoosh/core/services/account_balance_service.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/transaction.dart';

class AccountRepository {
  AccountRepository(this._client, this._cache, this._balanceService);

  final SupabaseClient _client;
  final LocalCache _cache;
  final AccountBalanceService _balanceService;

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

  Future<Account?> fetchById(String id) async {
    final data = await _client.from('accounts').select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return Account.fromJson(data);
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
    await _client.from('account_balance_snapshots').delete().eq('account_id', id);
    await _client.from('goals').update({'account_id': null}).eq('account_id', id);
    await _client
        .from('recurring_payments')
        .update({'account_id': null})
        .eq('account_id', id);
    await _client.from('transactions').delete().eq('account_id', id);
    await _client.from('accounts').delete().eq('id', id);
  }

  Future<void> recomputeBalance(String accountId) async {
    final account = await fetchById(accountId);
    if (account == null || !_balanceService.needsRecompute(account)) return;

    final txData = await _client
        .from('transactions')
        .select()
        .eq('account_id', accountId);
    final transactions =
        (txData as List).map((e) => Transaction.fromJson(e)).toList();
    final balance = _balanceService.computeBalance(account, transactions);
    await update(accountId, {'balance_pence': balance});
  }
}
