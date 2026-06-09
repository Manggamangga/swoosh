import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/core/cache/local_cache.dart';
import 'package:swoosh/core/utils/dedupe.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/transaction.dart';

class TransactionRepository {
  TransactionRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<Transaction>> fetchRecent({int limit = 50}) async {
    try {
      final data = await _client
          .from('transactions')
          .select('*, categories(name, color), accounts(name)')
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
        .select('*, categories(name, color), accounts(name)')
        .single();
    return Transaction.fromJson(data);
  }

  Future<void> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required int amountPence,
    required DateTime date,
    required String description,
    String? categoryId,
  }) async {
    final outHash = buildDedupeHash(
      accountId: fromAccountId,
      date: date,
      amountPence: -amountPence,
      description: description,
    );
    final inHash = buildDedupeHash(
      accountId: toAccountId,
      date: date,
      amountPence: amountPence,
      description: description,
    );

    final outTx = await _client
        .from('transactions')
        .insert({
          'account_id': fromAccountId,
          'transaction_date': date.toIso8601String().split('T').first,
          'amount_pence': -amountPence,
          'description': description,
          'category_id': categoryId,
          'source': DataSource.manual.name,
          'dedupe_hash': outHash,
          'exclude_from_analytics': true,
        })
        .select()
        .single();

    await _client.from('transactions').insert({
      'account_id': toAccountId,
      'transaction_date': date.toIso8601String().split('T').first,
      'amount_pence': amountPence,
      'description': description,
      'category_id': categoryId,
      'source': DataSource.manual.name,
      'dedupe_hash': inHash,
      'transfer_pair_id': outTx['id'],
      'exclude_from_analytics': true,
    });

    await _client.from('transactions').update({
      'transfer_pair_id': outTx['id'],
    }).eq('id', outTx['id']);
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
    return imported;
  }
}
