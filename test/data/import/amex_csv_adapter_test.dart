import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/data/import/adapters/amex_csv_adapter.dart';
import 'package:swoosh/models/account.dart';

void main() {
  late AmexCsvAdapter adapter;
  late Uint8List fixtureBytes;

  setUp(() async {
    adapter = AmexCsvAdapter();
    fixtureBytes = await File('test/fixtures/amex_export.csv').readAsBytes();
  });

  group('AmexCsvAdapter', () {
    test('matches Amex header columns without Account column', () {
      expect(
        AmexCsvAdapter.matchesHeader(const [
          'date',
          'description',
          'amount',
        ]),
        isTrue,
      );
      expect(
        AmexCsvAdapter.matchesHeader(const [
          'number',
          'date',
          'account',
          'amount',
          'memo',
        ]),
        isFalse,
      );
      expect(
        AmexCsvAdapter.matchesHeader(const [
          'date',
          'description',
          'amount',
          'account',
        ]),
        isFalse,
      );
    });

    test('parses dd/mm/yyyy dates', () async {
      final statement = await adapter.parse(fixtureBytes, 'amex_export.csv');

      expect(statement.transactions, hasLength(4));
      expect(
        statement.transactions.first.date,
        DateTime(2026, 5, 17),
      );
    });

    test('flips signs so purchases are negative and payments positive', () async {
      final statement = await adapter.parse(fixtureBytes, 'amex_export.csv');

      final purchase = statement.transactions.firstWhere(
        (tx) => tx.description.contains('TESCO PETROL'),
      );
      expect(purchase.amountPence, -7269);

      final payment = statement.transactions.firstWhere(
        (tx) => tx.description.contains('PAYMENT RECEIVED'),
      );
      expect(payment.amountPence, 58834);

      final amazon = statement.transactions.firstWhere(
        (tx) => tx.description.contains('AMAZON'),
      );
      expect(amazon.amountPence, -3499);
    });

    test('flags payment received as excludeFromAnalytics', () async {
      final statement = await adapter.parse(fixtureBytes, 'amex_export.csv');

      final payment = statement.transactions.firstWhere(
        (tx) => tx.description.contains('PAYMENT RECEIVED'),
      );
      expect(payment.excludeFromAnalytics, isTrue);

      final purchase = statement.transactions.firstWhere(
        (tx) => tx.description.contains('TESCO PETROL'),
      );
      expect(purchase.excludeFromAnalytics, isFalse);
    });

    test('returns credit account metadata', () async {
      final statement = await adapter.parse(fixtureBytes, 'amex_export.csv');

      expect(statement.institution, 'Amex');
      expect(statement.accountType, AccountType.credit);
      expect(statement.isCreditAccount, isTrue);
      expect(statement.closingBalancePence, isNull);
      expect(statement.currency, 'GBP');
    });

    test('detects payment received case-insensitively', () {
      expect(
        AmexCsvAdapter.isPaymentReceived('payment received - thank you'),
        isTrue,
      );
      expect(
        AmexCsvAdapter.isPaymentReceived('PAYMENT RECEIVED - THANK YOU'),
        isTrue,
      );
      expect(AmexCsvAdapter.isPaymentReceived('TESCO PETROL'), isFalse);
    });
  });
}
