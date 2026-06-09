import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/recurring_payment.dart';
import 'package:swoosh/models/transaction.dart';

class ForecastPoint {
  const ForecastPoint({required this.date, required this.balancePence});

  final DateTime date;
  final int balancePence;
}

class ForecastService {
  List<ForecastPoint> forecast({
    required List<Account> accounts,
    required List<RecurringPayment> recurring,
    required List<Transaction> expectedIncome,
    int daysAhead = 90,
  }) {
    final startBalance = accounts.fold<int>(0, (sum, a) => sum + a.balancePence);
    final start = DateTime.now();
    final end = start.add(Duration(days: daysAhead));
    final events = <DateTime, int>{};

    for (final payment in recurring) {
      var date = payment.nextDate;
      while (date.isBefore(end) || date.isAtSameMomentAs(end)) {
        if (!date.isBefore(start)) {
          events[DateTime(date.year, date.month, date.day)] =
              (events[DateTime(date.year, date.month, date.day)] ?? 0) +
                  payment.amountPence;
        }
        date = _advance(payment.cadence, date);
      }
    }

    for (final tx in expectedIncome) {
      if (!tx.excludeFromAnalytics && tx.amountPence > 0) {
        final d = DateTime(
          tx.transactionDate.year,
          tx.transactionDate.month,
          tx.transactionDate.day,
        );
        if (!d.isBefore(start) && !d.isAfter(end)) {
          events[d] = (events[d] ?? 0) + tx.amountPence;
        }
      }
    }

    final points = <ForecastPoint>[];
    var balance = startBalance;
    var cursor = DateTime(start.year, start.month, start.day);

    while (!cursor.isAfter(end)) {
      balance += events[cursor] ?? 0;
      points.add(ForecastPoint(date: cursor, balancePence: balance));
      cursor = cursor.add(const Duration(days: 1));
    }

    return points;
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
