import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/core/utils/dedupe.dart';
import 'package:swoosh/data/import/adapters/barclays_csv_adapter.dart';
import 'package:swoosh/data/import/csv_parse_utils.dart';

void main() {
  late BarclaysCsvAdapter adapter;
  late Uint8List fixtureBytes;

  setUp(() async {
    adapter = BarclaysCsvAdapter();
    fixtureBytes = await File('test/fixtures/barclays_export.csv').readAsBytes();
  });

  group('BarclaysCsvAdapter', () {
    test('matches Barclays header columns', () {
      expect(
        BarclaysCsvAdapter.matchesHeader(const [
          'number',
          'date',
          'account',
          'amount',
          'subcategory',
          'memo',
        ]),
        isTrue,
      );
      expect(
        BarclaysCsvAdapter.matchesHeader(const [
          'date',
          'description',
          'amount',
        ]),
        isFalse,
      );
    });

    test('parses dd/mm/yyyy dates', () async {
      final statement = await adapter.parse(
        fixtureBytes,
        'BarclaysExport.csv',
      );

      expect(statement.transactions, isNotEmpty);
      expect(
        statement.transactions.first.date,
        DateTime(2026, 5, 28),
      );
      expect(
        statement.transactions
            .firstWhere((tx) => tx.description.contains('SEAN WISE FT'))
            .date,
        DateTime(2026, 5, 26),
      );
    });

    test('converts signed decimal amounts to pence', () async {
      final statement = await adapter.parse(
        fixtureBytes,
        'BarclaysExport.csv',
      );

      final credit = statement.transactions.firstWhere(
        (tx) => tx.description.contains('MTCE LIMITED'),
      );
      expect(credit.amountPence, 133318);

      final debit = statement.transactions.firstWhere(
        (tx) => tx.description.contains('SEAN WISE FT'),
      );
      expect(debit.amountPence, -100000);

      final directDebit = statement.transactions.firstWhere(
        (tx) => tx.description.contains('SKY DIGITAL'),
      );
      expect(directDebit.amountPence, -2200);
    });

    test('extracts account identifier from Account column', () async {
      final statement = await adapter.parse(
        fixtureBytes,
        'BarclaysExport.csv',
      );

      expect(statement.accountIdentifier, '20-92-54 93172724');
      expect(statement.institution, 'Barclays');
      expect(statement.closingBalancePence, isNull);
      expect(statement.currency, 'GBP');
    });

    test('normalizes account identifier spacing', () {
      expect(
        normalizeAccountIdentifier('20-92-54  93172724'),
        '20-92-54 93172724',
      );
    });

    test('builds dedupe hash compatible with import rows', () async {
      const accountId = 'acc-barclays-1';
      final statement = await adapter.parse(
        fixtureBytes,
        'BarclaysExport.csv',
      );
      final tx = statement.transactions.first;

      final hash = buildDedupeHash(
        accountId: accountId,
        date: tx.date,
        amountPence: tx.amountPence,
        description: tx.description,
      );

      expect(hash, isNotEmpty);
      expect(
        buildDedupeHash(
          accountId: accountId,
          date: tx.date,
          amountPence: tx.amountPence,
          description: tx.description,
        ),
        hash,
      );
    });
  });
}
