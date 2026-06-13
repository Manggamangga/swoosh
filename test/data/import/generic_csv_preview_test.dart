import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/data/import/adapters/generic_csv_adapter.dart';

void main() {
  final adapter = GenericCsvAdapter();

  group('GenericCsvPreview', () {
    test('builds column mapping and sample transactions', () {
      const csv = 'Date,Description,Amount,Balance\n'
          '01/06/2025,Groceries,-12.50,987.50\n'
          '02/06/2025,Salary,1500.00,2487.50\n'
          '03/06/2025,Coffee,-2.50,2485.00';
      final bytes = Uint8List.fromList(utf8.encode(csv));

      final preview = adapter.preview(bytes, 'export.csv');

      expect(preview.hasRequiredColumns, isTrue);
      expect(preview.errorMessage, isNull);
      expect(preview.columnMapping['Date'], 'Date');
      expect(preview.columnMapping['Description'], 'Description');
      expect(preview.columnMapping['Amount'], 'Amount');
      expect(preview.columnMapping['Balance'], 'Balance');
      expect(preview.balanceFieldName, 'Balance');
      expect(preview.totalDataRows, 3);
      expect(preview.statement.transactions, hasLength(3));
      expect(preview.sampleTransactions, hasLength(3));
      expect(preview.statement.closingBalancePence, 248500);
      expect(preview.accountName, 'Unknown');
    });

    test('returns clear error when required columns are missing', () {
      const csv = 'Reference,Notes\nabc,def';
      final preview = adapter.preview(
        Uint8List.fromList(utf8.encode(csv)),
        'broken.csv',
      );

      expect(preview.hasRequiredColumns, isFalse);
      expect(preview.errorMessage, contains('Date and Description'));
      expect(preview.statement.transactions, isEmpty);
    });

    test('returns clear error when amount columns are missing', () {
      const csv = 'Date,Description\n01/06/2025,Shop';
      final preview = adapter.preview(
        Uint8List.fromList(utf8.encode(csv)),
        'broken.csv',
      );

      expect(preview.hasRequiredColumns, isFalse);
      expect(preview.errorMessage, contains('Amount or Debit/Credit'));
    });
  });
}
