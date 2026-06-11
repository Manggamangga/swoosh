import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/budget.dart';
import 'package:swoosh/models/recurring_payment.dart';

class SafeToSpendResult {
  const SafeToSpendResult({
    required this.amountPence,
    required this.everydayBalancePence,
    required this.upcomingRecurringPence,
    required this.remainingBudgetPence,
    this.nextIncomeDate,
    this.nextIncomeAmountPence,
  });

  final int amountPence;
  final int everydayBalancePence;
  final int upcomingRecurringPence;
  final int remainingBudgetPence;
  final DateTime? nextIncomeDate;
  final int? nextIncomeAmountPence;
}

class SafeToSpendService {
  SafeToSpendResult calculate({
    required List<Account> accounts,
    required List<RecurringPayment> recurring,
    required List<Budget> budgets,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final everydayBalance = accounts
        .where((account) => account.accountType == AccountType.everyday)
        .fold<int>(0, (sum, account) => sum + account.balancePence);

    final incomePayments = recurring.where((p) => p.amountPence > 0).toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));

    DateTime? nextIncomeDate;
    int? nextIncomeAmount;
    for (final payment in incomePayments) {
      var date = payment.nextDate;
      while (date.isBefore(today)) {
        date = _advance(payment.cadence, date);
      }
      nextIncomeDate = date;
      nextIncomeAmount = payment.amountPence;
      break;
    }

    final horizon = nextIncomeDate ?? today.add(const Duration(days: 30));

    final upcomingRecurring = recurring
        .where((payment) => payment.amountPence < 0)
        .where(
          (payment) =>
              !payment.nextDate.isBefore(today) &&
              !payment.nextDate.isAfter(horizon),
        )
        .fold<int>(0, (sum, payment) => sum + payment.amountPence);

    final remainingBudget = budgets.fold<int>(0, (sum, budget) {
      final remaining = budget.amountPence - budget.spentPence;
      return sum + (remaining > 0 ? remaining : 0);
    });

    final safeToSpend =
        everydayBalance + upcomingRecurring - remainingBudget;

    return SafeToSpendResult(
      amountPence: safeToSpend,
      everydayBalancePence: everydayBalance,
      upcomingRecurringPence: upcomingRecurring,
      remainingBudgetPence: remainingBudget,
      nextIncomeDate: nextIncomeDate,
      nextIncomeAmountPence: nextIncomeAmount,
    );
  }

  DateTime _advance(RecurringCadence cadence, DateTime date) {
    switch (cadence) {
      case RecurringCadence.weekly:
        return date.add(const Duration(days: 7));
      case RecurringCadence.monthly:
        return DateTime(date.year, date.month + 1, date.day);
      case RecurringCadence.quarterly:
        return DateTime(date.year, date.month + 3, date.day);
      case RecurringCadence.yearly:
        return DateTime(date.year + 1, date.month, date.day);
    }
  }
}
