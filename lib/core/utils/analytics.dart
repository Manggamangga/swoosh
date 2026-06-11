import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/transaction.dart';

Set<String> everydayAccountIds(List<Account> accounts) {
  return accounts
      .where((a) => a.accountType == AccountType.everyday)
      .map((a) => a.id)
      .toSet();
}

List<Transaction> everydayTransactions(
  List<Transaction> transactions,
  Set<String> everydayIds,
) {
  return transactions
      .where(
        (t) => everydayIds.contains(t.accountId) && !t.excludeFromAnalytics,
      )
      .toList();
}

int sumSpending(List<Transaction> transactions) {
  return transactions
      .where((t) => t.amountPence < 0)
      .fold<int>(0, (sum, t) => sum + t.amountPence.abs());
}

int sumIncome(List<Transaction> transactions) {
  return transactions
      .where((t) => t.amountPence > 0)
      .fold<int>(0, (sum, t) => sum + t.amountPence);
}

bool isInMonth(DateTime date, DateTime month) {
  return date.year == month.year && date.month == month.month;
}

DateTime monthStart(DateTime month) =>
    DateTime(month.year, month.month, 1);

DateTime monthEnd(DateTime month) =>
    DateTime(month.year, month.month + 1, 0);
