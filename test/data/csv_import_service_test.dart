import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/data/csv_import_service.dart';

void main() {
  final service = CsvImportService();

  group('parseStatement', () {
    test('parses amount column and dd/mm/yyyy dates', () {
      const csv =
          'Date,Description,Amount\n01/06/2025,Groceries,-12.50\n02/06/2025,Salary,1500.00';

      final result = service.parseStatement(
        accountId: 'acc-1',
        csvContent: csv,
        fileName: 'statement.csv',
      );

      expect(result.rows, hasLength(2));
      expect(result.rows.first['amount_pence'], -1250);
      expect(result.rows.last['amount_pence'], 150000);
      expect(result.rows.first['transaction_date'], '2025-06-01');
    });

    test('parses debit and credit columns', () {
      const csv =
          'Date,Description,Debit,Credit\n2025-06-01,Rent,800.00,\n2025-06-02,Pay,,2000.00';

      final result = service.parseStatement(
        accountId: 'acc-1',
        csvContent: csv,
      );

      expect(result.rows.first['amount_pence'], -80000);
      expect(result.rows.last['amount_pence'], 200000);
    });

    test('returns closing balance from latest dated row', () {
      const csv = 'Date,Description,Amount,Balance\n'
          '01/06/2025,Groceries,-10.00,990.00\n'
          '03/06/2025,Coffee,-2.50,987.50\n'
          '02/06/2025,Refund,5.00,992.50';

      final result = service.parseStatement(
        accountId: 'acc-1',
        csvContent: csv,
      );

      expect(result.closingBalancePence, 98750);
    });

    test('returns null closing balance when no balance column', () {
      const csv = 'Date,Description,Amount\n01/06/2025,Groceries,-10.00';

      final result = service.parseStatement(
        accountId: 'acc-1',
        csvContent: csv,
      );

      expect(result.closingBalancePence, isNull);
    });

    test('infers Barclays from filename', () {
      const csv = 'Date,Description,Amount\n01/06/2025,Shop,-5.00';

      final result = service.parseStatement(
        accountId: 'acc-1',
        csvContent: csv,
        fileName: 'barclays-june-2025.csv',
      );

      expect(result.institution, 'Barclays');
    });

    test('infers Amex from header text', () {
      const csv = 'American Express Card Statement\n'
          'Date,Description,Amount\n'
          '01/06/2025,Shop,-5.00';

      final result = service.parseStatement(
        accountId: 'acc-1',
        csvContent: csv,
      );

      expect(result.institution, 'Amex');
    });

    test('returns null institution when unknown', () {
      const csv = 'Date,Description,Amount\n01/06/2025,Shop,-5.00';

      final result = service.parseStatement(
        accountId: 'acc-1',
        csvContent: csv,
        fileName: 'export.csv',
      );

      expect(result.institution, isNull);
    });
  });
}
