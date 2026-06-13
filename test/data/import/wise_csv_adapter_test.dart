import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/core/services/transfer_noise_classifier.dart';
import 'package:swoosh/data/import/adapters/wise_csv_adapter.dart';
import 'package:swoosh/data/import/parsed_statement.dart';
import 'package:swoosh/data/import/statement_detector.dart';

void main() {
  late WiseCsvAdapter adapter;
  late Uint8List fixtureBytes;
  late TransferNoiseClassifier classifier;

  setUp(() async {
    adapter = WiseCsvAdapter();
    classifier = TransferNoiseClassifier();
    fixtureBytes = await File('test/fixtures/wise_export.csv').readAsBytes();
  });

  ParsedStatement classify(ParsedStatement statement) {
    final transactions = statement.transactions.map((tx) {
      final result = classifier.classifyTransaction(
        description: tx.description,
        amountPence: tx.amountPence,
        metadata: tx.metadata,
      );
      if (!result.isExcluded) return tx;
      return tx.copyWith(excludeFromAnalytics: true);
    }).toList();

    return ParsedStatement(
      institution: statement.institution,
      accountIdentifier: statement.accountIdentifier,
      transactions: transactions,
      closingBalancePence: statement.closingBalancePence,
      currency: statement.currency,
      accountType: statement.accountType,
    );
  }

  group('WiseCsvAdapter', () {
    test('matches Wise header columns', () {
      expect(
        WiseCsvAdapter.matchesHeader(const [
          'transferwise id',
          'date',
          'amount',
          'currency',
          'description',
          'running balance',
          'transaction details type',
        ]),
        isTrue,
      );
      expect(
        WiseCsvAdapter.matchesHeader(const [
          'date',
          'description',
          'amount',
        ]),
        isFalse,
      );
    });

    test('parses dd-mm-yyyy dates', () async {
      final statement = await adapter.parse(fixtureBytes, 'wise_export.csv');

      expect(statement.transactions, isNotEmpty);
      expect(
        statement.transactions.firstWhere(
          (tx) => tx.description.contains('TESCO'),
        ).date,
        DateTime(2026, 6, 10),
      );
    });

    test('anchors closing balance from latest running balance row', () async {
      final statement = await adapter.parse(fixtureBytes, 'wise_export.csv');

      expect(statement.closingBalancePence, 125401);
      expect(statement.institution, 'Wise');
      expect(statement.currency, 'GBP');
    });

    test('converts non-GBP amounts using exchange rate', () async {
      final statement = await adapter.parse(fixtureBytes, 'wise_export.csv');

      final amazon = statement.transactions.firstWhere(
        (tx) => tx.description.contains('AMAZON'),
      );
      expect(amazon.amountPence, -2015);
      expect(amazon.description, contains('USD'));
      expect(amazon.description, contains('→ GBP'));
    });

    test('keeps GBP card payments as expenses', () async {
      final statement = classify(
        await adapter.parse(fixtureBytes, 'wise_export.csv'),
      );

      final tesco = statement.transactions.firstWhere(
        (tx) => tx.description.contains('TESCO'),
      );
      expect(tesco.amountPence, -4599);
      expect(tesco.excludeFromAnalytics, isFalse);
    });

    test('flags noise and transfer rows via classifier', () async {
      final statement = classify(
        await adapter.parse(fixtureBytes, 'wise_export.csv'),
      );

      expect(
        statement.transactions
            .firstWhere((tx) => tx.description.contains('Sent money to Sean'))
            .excludeFromAnalytics,
        isTrue,
      );
      expect(
        statement.transactions
            .firstWhere((tx) => tx.description.contains('Converted GBP'))
            .excludeFromAnalytics,
        isTrue,
      );
      expect(
        statement.transactions
            .firstWhere((tx) => tx.description.contains('Topped up account'))
            .excludeFromAnalytics,
        isTrue,
      );
      expect(
        statement.transactions
            .firstWhere((tx) => tx.description.contains('Wise Assets fee'))
            .excludeFromAnalytics,
        isTrue,
      );
      expect(
        statement.transactions
            .firstWhere((tx) => tx.description.contains('Investment trade'))
            .excludeFromAnalytics,
        isTrue,
      );
      expect(
        statement.transactions
            .firstWhere((tx) => tx.description.contains('LOH S'))
            .excludeFromAnalytics,
        isTrue,
      );
    });

    test('keeps genuine income from other people', () async {
      final statement = classify(
        await adapter.parse(fixtureBytes, 'wise_export.csv'),
      );

      final income = statement.transactions.firstWhere(
        (tx) => tx.description.contains('Jeslyn Cheong'),
      );
      expect(income.amountPence, 25000);
      expect(income.excludeFromAnalytics, isFalse);
    });
  });

  group('StatementDetector', () {
    test('detects Wise adapter from fixture headers', () {
      final detector = StatementDetector();
      final adapter = detector.detect(fixtureBytes, 'wise_export.csv');
      expect(adapter, isA<WiseCsvAdapter>());
    });
  });
}
