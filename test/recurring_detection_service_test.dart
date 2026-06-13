import 'package:swoosh/core/services/recurring_detection_service.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/recurring_payment.dart';
import 'package:swoosh/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx({
  required String id,
  required DateTime date,
  required int amountPence,
  String merchant = 'Netflix',
}) {
  final now = DateTime.now();
  return Transaction(
    id: id,
    userId: 'user-1',
    accountId: 'acct-1',
    transactionDate: date,
    amountPence: amountPence,
    currency: 'GBP',
    description: merchant,
    merchant: merchant,
    source: DataSource.csv,
    dedupeHash: '$id-hash',
    excludeFromAnalytics: false,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final service = RecurringDetectionService();

  test('detects monthly recurring expenses with metadata', () {
    final detected = service.detect(
      transactions: [
        _tx(id: '1', date: DateTime(2025, 1, 15), amountPence: -999),
        _tx(id: '2', date: DateTime(2025, 2, 15), amountPence: -999),
        _tx(id: '3', date: DateTime(2025, 3, 15), amountPence: -999),
      ],
    );

    expect(detected, hasLength(1));
    expect(detected.first.name, 'Netflix');
    expect(detected.first.cadence, RecurringCadence.monthly);
    expect(detected.first.typicalAmountPence, 999);
    expect(detected.first.monthlyTotalPence, 999);
    expect(detected.first.occurrenceCount, 3);
    expect(detected.first.lastSeenDate, DateTime(2025, 3, 15));
  });

  test('ignores excluded and non-recurring transactions', () {
    final detected = service.detect(
      transactions: [
        _tx(id: '1', date: DateTime(2025, 1, 1), amountPence: -500),
        _tx(
          id: '2',
          date: DateTime(2025, 6, 1),
          amountPence: -500,
          merchant: 'One-off shop',
        ),
        _tx(
          id: '3',
          date: DateTime(2025, 1, 10),
          amountPence: -999,
        ).copyWithExcluded(true),
      ],
    );

    expect(detected, isEmpty);
  });

  test('computes weekly monthly equivalent', () {
    final detected = service.detect(
      transactions: [
        _tx(id: '1', date: DateTime(2025, 1, 1), amountPence: -1000),
        _tx(id: '2', date: DateTime(2025, 1, 8), amountPence: -1000),
        _tx(id: '3', date: DateTime(2025, 1, 15), amountPence: -1000),
      ],
    );

    expect(detected.first.cadence, RecurringCadence.weekly);
    expect(detected.first.monthlyTotalPence, (1000 * 52 / 12).round());
  });
}

extension on Transaction {
  Transaction copyWithExcluded(bool exclude) {
    return Transaction(
      id: id,
      userId: userId,
      accountId: accountId,
      transactionDate: transactionDate,
      amountPence: amountPence,
      currency: currency,
      description: description,
      merchant: merchant,
      categoryId: categoryId,
      source: source,
      externalRef: externalRef,
      dedupeHash: dedupeHash,
      transferPairId: transferPairId,
      excludeFromAnalytics: exclude,
      createdAt: createdAt,
      updatedAt: updatedAt,
      categoryName: categoryName,
      categoryColor: categoryColor,
      accountName: accountName,
    );
  }
}
