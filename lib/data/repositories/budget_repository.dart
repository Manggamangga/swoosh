import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/models/budget.dart';
import 'package:swoosh/models/transaction.dart';

class BudgetRepository {
  BudgetRepository(this._client);

  final SupabaseClient _client;

  Future<List<Budget>> fetchForMonth(DateTime month) async {
    final period = DateTime(month.year, month.month, 1);
    final data = await _client
        .from('budgets')
        .select('*, categories(name, color)')
        .eq('period_month', period.toIso8601String().split('T').first);
    return (data as List).map((e) => Budget.fromJson(e)).toList();
  }

  Future<Budget> upsert(Budget budget) async {
    final data = await _client
        .from('budgets')
        .upsert(budget.toJson(), onConflict: 'user_id,category_id,period_month')
        .select('*, categories(name, color)')
        .single();
    return Budget.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _client.from('budgets').delete().eq('id', id);
  }

  List<Budget> withSpent(List<Budget> budgets, List<Transaction> transactions) {
    if (budgets.isEmpty) return budgets;
    final start = DateTime(
      budgets.first.periodMonth.year,
      budgets.first.periodMonth.month,
      1,
    );
    final end = DateTime(start.year, start.month + 1, 0);

    return budgets.map((budget) {
      final spent = transactions
          .where((t) =>
              t.categoryId == budget.categoryId &&
              t.amountPence < 0 &&
              !t.excludeFromAnalytics &&
              !t.transactionDate.isBefore(start) &&
              !t.transactionDate.isAfter(end))
          .fold<int>(0, (sum, t) => sum + t.amountPence.abs());
      return budget.copyWith(spentPence: spent);
    }).toList();
  }
}
