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
    List<BalancePoint> snapshots = const [],
  }) {
    if (snapshots.isNotEmpty) {
      return _buildFromSnapshots(
        snapshots: snapshots,
        accounts: accounts,
        transactions: transactions,
        start: start,
        end: end,
      );
    }

    return _buildDerived(
      accounts: accounts,
      transactions: transactions,
      start: start,
      end: end,
    );
  }

  List<BalancePoint> _buildFromSnapshots({
    required List<BalancePoint> snapshots,
    required List<Account> accounts,
    required List<Transaction> transactions,
    required DateTime start,
    required DateTime end,
  }) {
    final snapshotByDay = {
      for (final point in snapshots)
        DateTime(point.date.year, point.date.month, point.date.day): point.balancePence,
    };

    final accountIds = accounts.map((a) => a.id).toSet();

    final points = <BalancePoint>[];
    var cursor = DateTime(end.year, end.month, end.day);
    final startDay = DateTime(start.year, start.month, start.day);

    var manualRunning = accounts.fold<int>(
      0,
      (sum, account) => sum + account.balancePence,
    );

    final relevant = transactions
        .where((t) => accountIds.contains(t.accountId))
        .where(
          (t) =>
              !t.transactionDate.isBefore(start) &&
              !t.transactionDate.isAfter(end),
        )
        .toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    while (!cursor.isBefore(startDay)) {
      final snapshotBalance = snapshotByDay[cursor];
      final total = (snapshotBalance ?? 0) + manualRunning;
      points.add(BalancePoint(date: cursor, balancePence: total));

      final dayTx = relevant
          .where(
            (t) =>
                t.transactionDate.year == cursor.year &&
                t.transactionDate.month == cursor.month &&
                t.transactionDate.day == cursor.day,
          )
          .fold<int>(0, (sum, t) => sum + t.amountPence);
      manualRunning -= dayTx;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return points.reversed.toList();
  }

  List<BalancePoint> _buildDerived({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required DateTime start,
    required DateTime end,
  }) {
    final points = <BalancePoint>[];
    final currentBalance =
        accounts.fold<int>(0, (sum, a) => sum + a.balancePence);

    final relevant = transactions
        .where(
          (t) =>
              !t.transactionDate.isBefore(start) &&
              !t.transactionDate.isAfter(end),
        )
        .toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    var running = currentBalance;
    var cursor = DateTime(end.year, end.month, end.day);

    while (!cursor.isBefore(start)) {
      points.add(BalancePoint(date: cursor, balancePence: running));
      final dayTx = relevant
          .where(
            (t) =>
                t.transactionDate.year == cursor.year &&
                t.transactionDate.month == cursor.month &&
                t.transactionDate.day == cursor.day,
          )
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
