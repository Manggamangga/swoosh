import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/data/import/adapters/generic_csv_adapter.dart';

void main() {
  final adapter = GenericCsvAdapter();

  group('GenericCsvAdapter', () {
    test('parses amount column and dd/mm/yyyy dates', () async {
      const csv =
          'Date,Description,Amount\n01/06/2025,Groceries,-12.50\n02/06/2025,Salary,1500.00';
      final bytes = Uint8List.fromList(utf8.encode(csv));

      final result = await adapter.parse(bytes, 'statement.csv');

      expect(result.transactions, hasLength(2));
      expect(result.transactions.first.amountPence, -1250);
      expect(result.transactions.last.amountPence, 150000);
      expect(
        result.transactions.first.date,
        DateTime(2025, 6, 1),
      );
    });

    test('parses debit and credit columns', () async {
      const csv =
          'Date,Description,Debit,Credit\n2025-06-01,Rent,800.00,\n2025-06-02,Pay,,2000.00';

      final result = await adapter.parse(Uint8List.fromList(utf8.encode(csv)), 'statement.csv');

      expect(result.transactions.first.amountPence, -80000);
      expect(result.transactions.last.amountPence, 200000);
    });

    test('returns closing balance from latest dated row', () async {
      const csv = 'Date,Description,Amount,Balance\n'
          '01/06/2025,Groceries,-10.00,990.00\n'
          '03/06/2025,Coffee,-2.50,987.50\n'
          '02/06/2025,Refund,5.00,992.50';

      final result = await adapter.parse(Uint8List.fromList(utf8.encode(csv)), 'statement.csv');

      expect(result.closingBalancePence, 98750);
    });

    test('returns null closing balance when no balance column', () async {
      const csv = 'Date,Description,Amount\n01/06/2025,Groceries,-10.00';

      final result = await adapter.parse(Uint8List.fromList(utf8.encode(csv)), 'statement.csv');

      expect(result.closingBalancePence, isNull);
    });

    test('infers Barclays from filename', () async {
      const csv = 'Date,Description,Amount\n01/06/2025,Shop,-5.00';

      final result = await adapter.parse(
        Uint8List.fromList(utf8.encode(csv)),
        'barclays-june-2025.csv',
      );

      expect(result.institution, 'Barclays');
    });

    test('infers Amex from header text', () async {
      const csv = 'American Express Card Statement\n'
          'Date,Description,Amount\n'
          '01/06/2025,Shop,-5.00';

      final result = await adapter.parse(Uint8List.fromList(utf8.encode(csv)), 'export.csv');

      expect(result.institution, 'Amex');
    });

    test('returns Unknown institution when unrecognized', () async {
      const csv = 'Date,Description,Amount\n01/06/2025,Shop,-5.00';

      final result = await adapter.parse(Uint8List.fromList(utf8.encode(csv)), 'export.csv');

      expect(result.institution, 'Unknown');
    });

    test('preview reports missing date column', () {
      const csv = 'Memo,Amount\nShop,-5.00';

      final preview = adapter.preview(Uint8List.fromList(utf8.encode(csv)), 'export.csv');

      expect(preview.hasRequiredColumns, isFalse);
      expect(preview.errorMessage, contains('Date and Description'));
    });

    test('preview reports missing description column', () {
      const csv = 'Date,Amount\n01/06/2025,-5.00';

      final preview = adapter.preview(Uint8List.fromList(utf8.encode(csv)), 'export.csv');

      expect(preview.hasRequiredColumns, isFalse);
      expect(preview.errorMessage, contains('Date and Description'));
    });

    test('preview reports missing amount columns', () {
      const csv = 'Date,Description\n01/06/2025,Shop';

      final preview = adapter.preview(Uint8List.fromList(utf8.encode(csv)), 'export.csv');

      expect(preview.hasRequiredColumns, isFalse);
      expect(preview.errorMessage, contains('Amount or Debit/Credit'));
    });
  });
}
