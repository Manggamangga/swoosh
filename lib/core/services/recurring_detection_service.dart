import 'package:swoosh/models/detected_recurring.dart';
import 'package:swoosh/models/recurring_payment.dart';
import 'package:swoosh/models/transaction.dart';

class RecurringDetectionService {
  List<DetectedRecurring> detect({
    required List<Transaction> transactions,
  }) {
    final expenses = transactions
        .where((t) => t.amountPence < 0 && !t.excludeFromAnalytics)
        .toList();

    final groups = <String, List<Transaction>>{};
    for (final tx in expenses) {
      final key = _detectionKey(
        merchant: tx.merchant ?? tx.description,
        amountPence: tx.amountPence.abs(),
      );
      groups.putIfAbsent(key, () => []).add(tx);
    }

    final detected = <DetectedRecurring>[];
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

      final amounts = txs.map((t) => t.amountPence.abs()).toList();
      final typicalAmount = _median(amounts);
      final last = txs.last;

      detected.add(
        DetectedRecurring(
          detectionKey: entry.key,
          name: last.merchant ?? last.description,
          typicalAmountPence: typicalAmount,
          cadence: cadence,
          monthlyTotalPence: _monthlyEquivalent(typicalAmount, cadence),
          lastSeenDate: last.transactionDate,
          occurrenceCount: txs.length,
          accountId: last.accountId,
          categoryId: last.categoryId,
          currency: last.currency,
        ),
      );
    }

    return detected;
  }

  static String detectionKeyFor({
    required String name,
    required int amountPence,
  }) =>
      _detectionKey(merchant: name, amountPence: amountPence.abs());

  static String _detectionKey({
    required String merchant,
    required int amountPence,
  }) {
    final normalized = merchant.trim().toLowerCase();
    return '$normalized|$amountPence';
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

  int _monthlyEquivalent(int amountPence, RecurringCadence cadence) {
    switch (cadence) {
      case RecurringCadence.weekly:
        return (amountPence * 52 / 12).round();
      case RecurringCadence.monthly:
        return amountPence;
      case RecurringCadence.quarterly:
        return (amountPence / 3).round();
      case RecurringCadence.yearly:
        return (amountPence / 12).round();
    }
  }

  int _median(List<int> values) {
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  DateTime nextDateFrom(RecurringCadence cadence, DateTime lastSeen) {
    switch (cadence) {
      case RecurringCadence.weekly:
        return lastSeen.add(const Duration(days: 7));
      case RecurringCadence.monthly:
        return DateTime(lastSeen.year, lastSeen.month + 1, lastSeen.day);
      case RecurringCadence.quarterly:
        return DateTime(lastSeen.year, lastSeen.month + 3, lastSeen.day);
      case RecurringCadence.yearly:
        return DateTime(lastSeen.year + 1, lastSeen.month, lastSeen.day);
    }
  }
}
