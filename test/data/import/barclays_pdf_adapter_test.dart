import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/data/import/adapters/barclays_pdf_adapter.dart';
import 'package:swoosh/data/import/csv_parse_utils.dart';

void main() {
  late BarclaysPdfAdapter adapter;
  late String fixtureText;

  setUp(() async {
    adapter = BarclaysPdfAdapter();
    fixtureText = await File('test/fixtures/barclays_statement.txt').readAsString();
  });

  group('BarclaysPdfAdapter', () {
    test('matches Barclays PDF content', () {
      expect(BarclaysPdfAdapter.matchesContent(fixtureText), isTrue);
      expect(
        BarclaysPdfAdapter.matchesContent('Some other bank statement'),
        isFalse,
      );
    });

    test('extracts account identifier and end balance', () {
      final statement = adapter.parseText(fixtureText);

      expect(statement.institution, 'Barclays');
      expect(statement.accountIdentifier, '20-92-54 93172724');
      expect(statement.closingBalancePence, 206174);
      expect(statement.currency, 'GBP');
    });

    test('parses short dates and signed amounts', () {
      final statement = adapter.parseText(fixtureText);

      expect(statement.transactions, hasLength(6));

      final mtce = statement.transactions.firstWhere(
        (tx) => tx.description.contains('MTCE LIMITED'),
      );
      expect(mtce.date, DateTime(2026, 5, 28));
      expect(mtce.amountPence, 133318);

      final sean = statement.transactions.firstWhere(
        (tx) => tx.description.contains('SEAN DARIAN'),
      );
      expect(sean.date, DateTime(2026, 5, 26));
      expect(sean.amountPence, -100000);

      final sky = statement.transactions.firstWhere(
        (tx) => tx.description.contains('SKY DIGITAL'),
      );
      expect(sky.amountPence, -2200);
    });

    test('merges multi-line descriptions and ref lines', () {
      final statement = adapter.parseText(fixtureText);

      final moneybox = statement.transactions.firstWhere(
        (tx) => tx.description.contains('MONEYBOX-922C5C424'),
      );
      expect(moneybox.description, contains('Ref:'));

      final mtce = statement.transactions.firstWhere(
        (tx) => tx.description.contains('MTCE LIMITED'),
      );
      expect(mtce.description, contains('Ref: 540114527 BGC'));
    });

    test('normalizes account identifier spacing', () {
      expect(
        normalizeAccountIdentifier('20-92-54  93172724'),
        '20-92-54 93172724',
      );
    });
  });
}
