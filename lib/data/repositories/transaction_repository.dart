import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/core/cache/local_cache.dart';
import 'package:swoosh/data/repositories/account_repository.dart';
import 'package:swoosh/models/transaction.dart';

class TransactionRepository {
  TransactionRepository(this._client, this._cache, this._accountRepo);

  final SupabaseClient _client;
  final LocalCache _cache;
  final AccountRepository _accountRepo;

  static const _selectWithJoins =
      '*, categories(name, color), accounts(name)';

  Future<List<Transaction>> fetchAll({int limit = 500}) async {
    final data = await _client
        .from('transactions')
        .select(_selectWithJoins)
        .order('transaction_date', ascending: false)
        .limit(limit);
    return (data as List).map((e) => Transaction.fromJson(e)).toList();
  }

  Future<List<Transaction>> fetchUncategorized({int limit = 1000}) async {
    final data = await _client
        .from('transactions')
        .select(_selectWithJoins)
        .isFilter('category_id', null)
        .order('transaction_date', ascending: false)
        .limit(limit);
    return (data as List).map((e) => Transaction.fromJson(e)).toList();
  }

  Future<Transaction> updateCategory({
    required String transactionId,
    required String categoryId,
  }) async {
    final data = await _client
        .from('transactions')
        .update({'category_id': categoryId})
        .eq('id', transactionId)
        .select(_selectWithJoins)
        .single();
    return Transaction.fromJson(data);
  }

  Future<Transaction> updateExcludeFromAnalytics({
    required String transactionId,
    required bool exclude,
  }) async {
    final data = await _client
        .from('transactions')
        .update({'exclude_from_analytics': exclude})
        .eq('id', transactionId)
        .select(_selectWithJoins)
        .single();
    return Transaction.fromJson(data);
  }

  Future<Transaction> update({
    required String transactionId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _client
        .from('transactions')
        .update(updates)
        .eq('id', transactionId)
        .select(_selectWithJoins)
        .single();
    final transaction = Transaction.fromJson(data);
    await _accountRepo.recomputeBalance(transaction.accountId);
    return transaction;
  }

  Future<void> delete(String transactionId) async {
    final existing = await _client
        .from('transactions')
        .select('account_id')
        .eq('id', transactionId)
        .single();
    final accountId = existing['account_id'] as String;
    await _client.from('transactions').delete().eq('id', transactionId);
    await _accountRepo.recomputeBalance(accountId);
  }

  Future<List<Transaction>> fetchRecent({int limit = 50}) async {
    try {
      final data = await _client
          .from('transactions')
          .select(_selectWithJoins)
          .order('transaction_date', ascending: false)
          .limit(limit);
      final list = (data as List).cast<Map<String, dynamic>>();
      await _cache.saveTransactions(list);
      return list.map(Transaction.fromJson).toList();
    } catch (_) {
      final cached = _cache.getTransactions();
      if (cached != null) {
        return cached.map(Transaction.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<List<Transaction>> fetchByAccount(String accountId) async {
    final data = await _client
        .from('transactions')
        .select('*, categories(name, color)')
        .eq('account_id', accountId)
        .order('transaction_date', ascending: false);
    return (data as List).map((e) => Transaction.fromJson(e)).toList();
  }

  Future<List<Transaction>> fetchForPeriod(DateTime start, DateTime end) async {
    final data = await _client
        .from('transactions')
        .select('*, categories(name, color)')
        .gte('transaction_date', start.toIso8601String().split('T').first)
        .lte('transaction_date', end.toIso8601String().split('T').first)
        .order('transaction_date', ascending: false);
    return (data as List).map((e) => Transaction.fromJson(e)).toList();
  }

  Future<Transaction> create(Transaction transaction) async {
    final data = await _client
        .from('transactions')
        .insert(transaction.toInsertJson())
        .select(_selectWithJoins)
        .single();
    final created = Transaction.fromJson(data);
    await _accountRepo.recomputeBalance(created.accountId);
    return created;
  }

  Future<int> importCsvRows({
    required String accountId,
    required List<Map<String, dynamic>> rows,
  }) async {
    var imported = 0;
    for (final row in rows) {
      try {
        await _client.from('transactions').insert(row);
        imported++;
      } catch (_) {}
    }
    if (imported > 0) {
      await _accountRepo.recomputeBalance(accountId);
    }
    return imported;
  }
}
