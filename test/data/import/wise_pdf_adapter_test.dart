import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/data/import/adapters/wise_pdf_adapter.dart';
import 'package:swoosh/data/import/statement_detector.dart';

void main() {
  late WisePdfAdapter adapter;
  late Uint8List fixtureBytes;
  late String fixtureText;

  setUp(() async {
    adapter = WisePdfAdapter();
    fixtureBytes = await File('test/fixtures/wise_statement.pdf').readAsBytes();
    fixtureText = adapter.extractText(fixtureBytes);
  });

  group('WisePdfAdapter', () {
    test('matches wise statement content', () {
      expect(WisePdfAdapter.matchesContent(fixtureText), isTrue);
    });

    test('extracts closing balance and account identifier', () {
      final statement = adapter.parseText(fixtureText);

      expect(statement.closingBalancePence, 504332);
      expect(statement.accountIdentifier, '21950405');
    });

    test('parses transactions with provider ids', () {
      final statement = adapter.parseText(fixtureText);

      expect(statement.transactions, isNotEmpty);
      final transfer = statement.transactions.firstWhere(
        (tx) => tx.providerTxnId == '2154499500',
      );
      expect(transfer.amountPence, 100000);
    });

    test('shares provider id numeric suffix with activity csv format', () {
      final statement = adapter.parseText(fixtureText);

      expect(
        statement.transactions.any((tx) => tx.providerTxnId == '5339545437'),
        isTrue,
      );
    });
  });

  group('StatementDetector', () {
    test('detects Wise PDF adapter', () {
      final detector = StatementDetector();
      final detected = detector.detect(fixtureBytes, 'wise_statement.pdf');
      expect(detected, isA<WisePdfAdapter>());
    });
  });
}
