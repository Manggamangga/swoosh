import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/budget.dart';
import 'package:swoosh/models/category.dart';
import 'package:swoosh/models/goal.dart';
import 'package:swoosh/models/recurring_payment.dart';
import 'package:swoosh/models/transaction.dart';
import 'package:swoosh/providers/providers.dart';

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final repo = await ref.watch(accountRepositoryProvider.future);
  return repo.fetchAll();
});

final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final repo = await ref.watch(transactionRepositoryProvider.future);
  return repo.fetchRecent();
});

final allTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final repo = await ref.watch(transactionRepositoryProvider.future);
  return repo.fetchAll();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.watch(categoryRepositoryProvider).fetchAll();
});

final budgetsProvider = FutureProvider<List<Budget>>((ref) async {
  final repo = ref.watch(budgetRepositoryProvider);
  final txRepo = await ref.watch(transactionRepositoryProvider.future);
  final now = DateTime.now();
  final budgets = await repo.fetchForMonth(now);
  final transactions = await txRepo.fetchForPeriod(
    DateTime(now.year, now.month, 1),
    DateTime(now.year, now.month + 1, 0),
  );
  return repo.withSpent(budgets, transactions);
});

final recurringProvider = FutureProvider<List<RecurringPayment>>((ref) async {
  return ref.watch(recurringRepositoryProvider).fetchAll();
});

final goalsProvider = FutureProvider<List<Goal>>((ref) async {
  return ref.watch(goalRepositoryProvider).fetchAll();
});

final monthlySummaryProvider = FutureProvider<MonthlySummary>((ref) async {
  final transactions = await ref.watch(transactionsProvider.future);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0);

  var income = 0;
  var spending = 0;
  for (final tx in transactions) {
    if (tx.excludeFromAnalytics) continue;
    if (tx.transactionDate.isBefore(start) || tx.transactionDate.isAfter(end)) {
      continue;
    }
    if (tx.amountPence > 0) {
      income += tx.amountPence;
    } else {
      spending += tx.amountPence.abs();
    }
  }

  return MonthlySummary(incomePence: income, spendingPence: spending);
});

class MonthlySummary {
  const MonthlySummary({
    required this.incomePence,
    required this.spendingPence,
  });

  final int incomePence;
  final int spendingPence;

  int get netPence => incomePence - spendingPence;
}
