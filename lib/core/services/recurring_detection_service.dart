import 'package:swoosh/models/recurring_payment.dart';
import 'package:swoosh/models/transaction.dart';

class RecurringDetectionService {
  List<RecurringPayment> detect({
    required String userId,
    required List<Transaction> transactions,
  }) {
    final expenses = transactions
        .where((t) => t.amountPence < 0 && !t.excludeFromAnalytics)
        .toList();

    final groups = <String, List<Transaction>>{};
    for (final tx in expenses) {
      final key = '${tx.merchant ?? tx.description}|${tx.amountPence.abs()}';
      groups.putIfAbsent(key, () => []).add(tx);
    }

    final detected = <RecurringPayment>[];
    for (final entry in groups.entries) {
      final txs = entry.value..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
      if (txs.length < 2) continue;

      final intervals = <int>[];
      for (var i = 1; i < txs.length; i++) {
        intervals.add(
          txs[i].transactionDate.difference(txs[i - 1].transactionDate).inDays,
        );
      }

      final cadence = _inferCadence(intervals);
      if (cadence == null) continue;

      final last = txs.last;
      detected.add(
        RecurringPayment(
          id: '',
          userId: userId,
          name: last.merchant ?? last.description,
          amountPence: last.amountPence,
          currency: last.currency,
          cadence: cadence,
          nextDate: _nextFromCadence(cadence, last.transactionDate),
          accountId: last.accountId,
          categoryId: last.categoryId,
          autoDetected: true,
        ),
      );
    }

    return detected;
  }

  RecurringCadence? _inferCadence(List<int> intervals) {
    if (intervals.isEmpty) return null;
    final avg = intervals.reduce((a, b) => a + b) / intervals.length;
    if (avg >= 5 && avg <= 10) return RecurringCadence.weekly;
    if (avg >= 25 && avg <= 35) return RecurringCadence.monthly;
    if (avg >= 80 && avg <= 100) return RecurringCadence.quarterly;
    if (avg >= 350 && avg <= 380) return RecurringCadence.yearly;
    return null;
  }

  DateTime _nextFromCadence(RecurringCadence cadence, DateTime last) {
    switch (cadence) {
      case RecurringCadence.weekly:
        return last.add(const Duration(days: 7));
      case RecurringCadence.monthly:
        return DateTime(last.year, last.month + 1, last.day);
      case RecurringCadence.quarterly:
        return DateTime(last.year, last.month + 3, last.day);
      case RecurringCadence.yearly:
        return DateTime(last.year + 1, last.month, last.day);
    }
  }
}
