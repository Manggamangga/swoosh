import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swoosh/core/services/balance_history_service.dart';
import 'package:swoosh/core/services/price_change_service.dart';
import 'package:swoosh/core/services/recurring_detection_service.dart';
import 'package:swoosh/core/services/safe_to_spend_service.dart';
import 'package:swoosh/core/utils/analytics.dart';
import 'package:swoosh/core/widgets/period_pills.dart';
import 'package:swoosh/features/home/home_balance_view.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/budget.dart';
import 'package:swoosh/models/category.dart';
import 'package:swoosh/models/detected_recurring.dart';
import 'package:swoosh/models/goal.dart';
import 'package:swoosh/models/recurring_payment.dart';
import 'package:swoosh/models/transaction.dart';
import 'package:swoosh/providers/onboarding_provider.dart';
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
  final now = DateTime.now();
  return ref.watch(budgetsForMonthProvider(DateTime(now.year, now.month, 1)).future);
});

final budgetsForMonthProvider = FutureProvider.family<List<Budget>, DateTime>(
  (ref, month) async {
    final repo = ref.watch(budgetRepositoryProvider);
    final accounts = await ref.watch(accountsProvider.future);
    final everydayIds = everydayAccountIds(accounts);
    final txRepo = await ref.watch(transactionRepositoryProvider.future);
    final start = monthStart(month);
    final end = monthEnd(month);
    final budgets = await repo.fetchForMonth(month);
    final transactions = everydayTransactions(
      await txRepo.fetchForPeriod(start, end),
      everydayIds,
    );
    return repo.withSpent(budgets, transactions);
  },
);

final recurringProvider = FutureProvider<List<RecurringPayment>>((ref) async {
  return ref.watch(recurringRepositoryProvider).fetchAll();
});

final goalsProvider = FutureProvider<List<Goal>>((ref) async {
  return ref.watch(goalRepositoryProvider).fetchAll();
});

final netWorthProvider = FutureProvider<int>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  return ref.watch(analyticsServiceProvider).computeNetWorth(accounts);
});

final monthlySummaryProvider = FutureProvider<MonthlySummary>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  final txRepo = await ref.watch(transactionRepositoryProvider.future);
  final now = DateTime.now();
  final start = monthStart(now);
  final end = monthEnd(now);
  final transactions = await txRepo.fetchForPeriod(start, end);
  final summary = ref.watch(analyticsServiceProvider).computeMonthlySummary(
        transactions,
        accounts,
      );

  return MonthlySummary(
    incomePence: summary.incomePence,
    spendingPence: summary.spendingPence,
  );
});

final chartTransactionsProvider =
    FutureProvider.family<List<Transaction>, ChartPeriod>((ref, period) async {
  final txRepo = await ref.watch(transactionRepositoryProvider.future);
  final now = DateTime.now();
  final start = period.startFrom(now);
  return txRepo.fetchForPeriod(start, now);
});

typedef BalanceHistoryKey = (ChartPeriod period, HomeBalanceView view);

final balanceHistoryProvider =
    FutureProvider.family<List<BalancePoint>, BalanceHistoryKey>((ref, key) async {
  final (period, view) = key;
  final accounts = await ref.watch(accountsProvider.future);
  final chartTransactions =
      await ref.watch(chartTransactionsProvider(period).future);
  final balanceService = ref.watch(balanceHistoryServiceProvider);

  final filtered = accountsForView(accounts, view);
  if (filtered.isEmpty) return const [];

  final now = DateTime.now();
  final start = period.startFrom(now);
  final accountIds = filtered.map((account) => account.id).toList();
  final periodTransactions = chartTransactions
      .where((transaction) => accountIds.contains(transaction.accountId))
      .toList();

  return balanceService.buildHistory(
    accounts: filtered,
    transactions: periodTransactions,
    start: start,
    end: now,
  );
});

final safeToSpendProvider = FutureProvider<SafeToSpendResult>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  final recurring = await ref.watch(recurringProvider.future);
  final budgets = await ref.watch(budgetsProvider.future);
  return ref.watch(safeToSpendServiceProvider).calculate(
        accounts: accounts,
        recurring: recurring,
        budgets: budgets,
      );
});

final priceChangeAlertsProvider = FutureProvider<List<PriceChangeAlert>>((ref) async {
  final recurring = await ref.watch(recurringProvider.future);
  final transactions = await ref.watch(allTransactionsProvider.future);
  return ref.watch(priceChangeServiceProvider).detect(
        recurring: recurring,
        transactions: transactions,
      );
});

final expectedIncomeProvider = FutureProvider<List<RecurringPayment>>((ref) async {
  final recurring = await ref.watch(recurringProvider.future);
  return recurring.where((payment) => payment.amountPence > 0).toList();
});

final spendingMonthProvider =
    FutureProvider.family<SpendingMonthData, DateTime>((ref, month) async {
  final accounts = await ref.watch(accountsProvider.future);
  final everydayIds = everydayAccountIds(accounts);
  final txRepo = await ref.watch(transactionRepositoryProvider.future);
  final budgetRepo = ref.watch(budgetRepositoryProvider);

  final currentStart = monthStart(month);
  final currentEnd = monthEnd(month);
  final prevMonth = DateTime(month.year, month.month - 1, 1);
  final prevStart = monthStart(prevMonth);

  final allTransactions = everydayTransactions(
    await txRepo.fetchForPeriod(prevStart, currentEnd),
    everydayIds,
  );
  final currentTransactions = allTransactions
      .where((t) => isInMonth(t.transactionDate, month))
      .toList();
  final previousTransactions = allTransactions
      .where((t) => isInMonth(t.transactionDate, prevMonth))
      .toList();

  final budgets = await budgetRepo.fetchForMonth(month);
  final budgetsWithSpent = budgetRepo.withSpent(budgets, currentTransactions);
  final budgetByCategory = {
    for (final budget in budgetsWithSpent) budget.categoryId: budget,
  };
  final categories = await ref.watch(categoriesProvider.future);
  final iconByCategory = {for (final c in categories) c.id: c.icon};

  final currentByCategory = _groupSpendingByCategory(currentTransactions);
  final previousByCategory = _groupSpendingByCategory(previousTransactions);

  final categoryIds = {
    ...currentByCategory.keys,
    ...previousByCategory.keys,
  };

  final rows = categoryIds.map((categoryId) {
    final budget = budgetByCategory[categoryId];
    final current = currentByCategory[categoryId];
    return CategorySpendingRow(
      categoryId: categoryId,
      categoryName: current?.name ?? budget?.categoryName ?? 'Uncategorized',
      categoryColor: current?.color ?? budget?.categoryColor ?? '#64748B',
      categoryIcon: categoryId == '_uncategorized'
          ? 'category'
          : iconByCategory[categoryId] ?? 'category',
      spentPence: current?.spentPence ?? 0,
      previousSpentPence: previousByCategory[categoryId]?.spentPence ?? 0,
      budget: budget,
    );
  }).toList()
    ..sort((a, b) => b.spentPence.compareTo(a.spentPence));

  return SpendingMonthData(
    month: currentStart,
    totalSpentPence: sumSpending(currentTransactions),
    categories: rows,
  );
});

final topSpendingCategoriesProvider =
    FutureProvider<List<CategorySpendingRow>>((ref) async {
  final now = DateTime.now();
  final month = DateTime(now.year, now.month, 1);
  final data = await ref.watch(spendingMonthProvider(month).future);
  return data.categories.take(5).toList();
});

class EmergencyFundProgress {
  const EmergencyFundProgress({
    required this.currentPence,
    required this.targetPence,
  });

  final int currentPence;
  final int targetPence;

  int get remainingPence => (targetPence - currentPence).clamp(0, targetPence);

  double get progress =>
      targetPence == 0 ? 0 : (currentPence / targetPence).clamp(0.0, 1.0);
}

final emergencyFundProgressProvider =
    FutureProvider<EmergencyFundProgress?>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  final savingsTotal = accounts
      .where((account) => account.accountType == AccountType.savings)
      .fold<int>(0, (sum, account) => sum + account.balancePence);

  final goals = await ref.watch(goalsProvider.future);
  Goal? emergencyGoal;
  for (final goal in goals) {
    if (goal.name.toLowerCase().contains('emergency')) {
      emergencyGoal = goal;
      break;
    }
  }

  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final targetFromPrefs = prefs.getInt('emergency_fund_target_pence');
  final target = emergencyGoal?.targetAmountPence ?? targetFromPrefs;
  if (target == null || target <= 0) return null;

  final current = emergencyGoal?.currentAmountPence ?? savingsTotal;
  return EmergencyFundProgress(currentPence: current, targetPence: target);
});

final detectedRecurringProvider =
    FutureProvider<List<DetectedRecurring>>((ref) async {
  final transactions = await ref.watch(allTransactionsProvider.future);
  final confirmed = await ref.watch(recurringProvider.future);
  final dismissed = ref.watch(dismissedRecurringKeysProvider);

  final confirmedKeys = confirmed
      .map(
        (p) => RecurringDetectionService.detectionKeyFor(
          name: p.name,
          amountPence: p.amountPence,
        ),
      )
      .toSet();

  final detector = ref.watch(recurringDetectionServiceProvider);
  return detector
      .detect(transactions: transactions)
      .where(
        (d) =>
            !confirmedKeys.contains(d.detectionKey) &&
            !dismissed.contains(d.detectionKey),
      )
      .toList()
    ..sort((a, b) => b.monthlyTotalPence.compareTo(a.monthlyTotalPence));
});

class CategoryMonthPoint {
  const CategoryMonthPoint({
    required this.month,
    required this.spentPence,
  });

  final DateTime month;
  final int spentPence;
}

final categoryTrendProvider =
    FutureProvider.family<List<CategoryMonthPoint>, String>((ref, categoryId) async {
  final txRepo = await ref.watch(transactionRepositoryProvider.future);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 5, 1);
  final transactions = await txRepo.fetchForPeriod(start, now);

  final points = <CategoryMonthPoint>[];
  for (var i = 0; i < 6; i++) {
    final month = DateTime(now.year, now.month - (5 - i), 1);
    final spent = transactions
        .where(
          (t) =>
              t.amountPence < 0 &&
              !t.excludeFromAnalytics &&
              isInMonth(t.transactionDate, month) &&
              (categoryId == '_uncategorized'
                  ? t.categoryId == null
                  : t.categoryId == categoryId),
        )
        .fold<int>(0, (sum, t) => sum + t.amountPence.abs());
    points.add(CategoryMonthPoint(month: month, spentPence: spent));
  }
  return points;
});

final upcomingRecurringProvider =
    FutureProvider<List<RecurringPayment>>((ref) async {
  final recurring = await ref.watch(recurringProvider.future);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final windowEnd = today.add(const Duration(days: 30));

  return recurring
      .where(
        (payment) =>
            !payment.nextDate.isBefore(today) &&
            !payment.nextDate.isAfter(windowEnd),
      )
      .toList()
    ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
});

Map<String, _CategorySpend> _groupSpendingByCategory(
  List<Transaction> transactions,
) {
  final grouped = <String, _CategorySpend>{};
  for (final tx in transactions) {
    if (tx.amountPence >= 0) continue;
    final categoryId = tx.categoryId ?? '_uncategorized';
    final existing = grouped[categoryId];
    grouped[categoryId] = _CategorySpend(
      name: tx.categoryName ?? existing?.name ?? 'Uncategorized',
      color: tx.categoryColor ?? existing?.color ?? '#64748B',
      icon: existing?.icon ?? 'category',
      spentPence: (existing?.spentPence ?? 0) + tx.amountPence.abs(),
    );
  }
  return grouped;
}

class _CategorySpend {
  const _CategorySpend({
    required this.name,
    required this.color,
    required this.icon,
    required this.spentPence,
  });

  final String name;
  final String color;
  final String icon;
  final int spentPence;
}

class SpendingMonthData {
  const SpendingMonthData({
    required this.month,
    required this.totalSpentPence,
    required this.categories,
  });

  final DateTime month;
  final int totalSpentPence;
  final List<CategorySpendingRow> categories;
}

class CategorySpendingRow {
  const CategorySpendingRow({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.spentPence,
    required this.previousSpentPence,
    this.budget,
  });

  final String categoryId;
  final String categoryName;
  final String categoryColor;
  final String categoryIcon;
  final int spentPence;
  final int previousSpentPence;
  final Budget? budget;

  int get changePence => spentPence - previousSpentPence;
}

class MonthlySummary {
  const MonthlySummary({
    required this.incomePence,
    required this.spendingPence,
  });

  final int incomePence;
  final int spendingPence;

  int get netPence => incomePence - spendingPence;
}
