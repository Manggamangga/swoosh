import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/transaction.dart';

class BalancePoint {
  const BalancePoint({required this.date, required this.balancePence});

  final DateTime date;
  final int balancePence;
}

class BalanceHistoryService {
  List<BalancePoint> buildHistory({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required DateTime start,
    required DateTime end,
  }) {
    final points = <BalancePoint>[];
    final currentBalance =
        accounts.fold<int>(0, (sum, a) => sum + a.balancePence);

    final relevant = transactions
        .where((t) =>
            !t.transactionDate.isBefore(start) &&
            !t.transactionDate.isAfter(end))
        .toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    var running = currentBalance;
    var cursor = DateTime(end.year, end.month, end.day);

    while (!cursor.isBefore(start)) {
      points.add(BalancePoint(date: cursor, balancePence: running));
      final dayTx = relevant
          .where((t) =>
              t.transactionDate.year == cursor.year &&
              t.transactionDate.month == cursor.month &&
              t.transactionDate.day == cursor.day)
          .fold<int>(0, (sum, t) => sum + t.amountPence);
      running -= dayTx;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return points.reversed.toList();
  }

  int totalByType(List<Account> accounts, AccountType type) {
    return accounts
        .where((a) => a.accountType == type)
        .fold<int>(0, (sum, a) => sum + a.balancePence);
  }
}
