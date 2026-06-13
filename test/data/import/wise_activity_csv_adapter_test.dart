import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/data/import/adapters/wise_activity_csv_adapter.dart';
import 'package:swoosh/data/import/statement_detector.dart';

void main() {
  late WiseActivityCsvAdapter adapter;
  late Uint8List fixtureBytes;

  setUp(() async {
    adapter = WiseActivityCsvAdapter();
    fixtureBytes =
        await File('test/fixtures/wise_activity.csv').readAsBytes();
  });

  group('WiseActivityCsvAdapter', () {
    test('matches transaction-history header', () {
      expect(
        WiseActivityCsvAdapter.matchesHeader(const [
          'id',
          'status',
          'direction',
          'created on',
          'source amount (after fees)',
          'source currency',
          'target amount (after fees)',
          'target currency',
        ]),
        isTrue,
      );
    });

    test('extracts provider txn id from wise ids', () {
      expect(
        WiseActivityCsvAdapter.extractProviderTxnId('TRANSFER-2154499500'),
        '2154499500',
      );
      expect(
        WiseActivityCsvAdapter.extractProviderTxnId(
          '"BALANCE_TRANSACTION-5339545437"',
        ),
        '5339545437',
      );
    });

    test('parses GBP incoming transfer', () async {
      final statement =
          await adapter.parse(fixtureBytes, 'wise_activity.csv');

      final transfer = statement.transactions.firstWhere(
        (tx) => tx.providerTxnId == '2154499500',
      );
      expect(transfer.amountPence, 100000);
      expect(transfer.currency, 'GBP');
    });

    test('excludes NEUTRAL balance conversions', () async {
      final statement =
          await adapter.parse(fixtureBytes, 'wise_activity.csv');

      expect(
        statement.transactions.any((tx) => tx.providerTxnId == '5339545437'),
        isFalse,
      );
    });

    test('flags foreign card spend as excluded from analytics', () async {
      final statement =
          await adapter.parse(fixtureBytes, 'wise_activity.csv');

      final foreign = statement.transactions.firstWhere(
        (tx) => tx.description.contains('De Canto'),
      );
      expect(foreign.currency, 'EUR');
      expect(foreign.excludeFromAnalytics, isTrue);
    });
  });

  group('StatementDetector', () {
    test('detects Wise activity CSV adapter', () {
      final detector = StatementDetector();
      final detected = detector.detect(fixtureBytes, 'wise_activity.csv');
      expect(detected, isA<WiseActivityCsvAdapter>());
    });
  });
}
