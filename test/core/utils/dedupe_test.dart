import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/core/utils/dedupe.dart';
import 'package:swoosh/data/import/parsed_statement.dart';

void main() {
  group('buildDedupeHash', () {
    const accountId = 'acc-1';

    test('uses provider txn id when present', () {
      final hash = buildDedupeHash(
        accountId: accountId,
        date: DateTime(2026, 5, 26),
        amountPence: 100000,
        description: 'Received money from LOH S',
        providerTxnId: '2154499500',
      );

      final sameHash = buildDedupeHash(
        accountId: accountId,
        date: DateTime(2026, 1, 1),
        amountPence: 999,
        description: 'Different description',
        providerTxnId: '2154499500',
      );

      expect(hash, sameHash);
    });

    test('uses ordinal for identical-looking rows without provider id', () {
      final txs = [
        ParsedTransaction(
          date: DateTime(2026, 6, 10),
          amountPence: -145,
          description: 'TESCO STORE',
        ),
        ParsedTransaction(
          date: DateTime(2026, 6, 10),
          amountPence: -145,
          description: 'TESCO STORE',
        ),
      ];

      final ordinals = computeOrdinalMap(txs);
      expect(ordinals[txs[0]], 0);
      expect(ordinals[txs[1]], 1);

      final hash0 = buildDedupeHash(
        accountId: accountId,
        date: txs[0].date,
        amountPence: txs[0].amountPence,
        description: txs[0].description,
        ordinal: ordinals[txs[0]]!,
      );
      final hash1 = buildDedupeHash(
        accountId: accountId,
        date: txs[1].date,
        amountPence: txs[1].amountPence,
        description: txs[1].description,
        ordinal: ordinals[txs[1]]!,
      );

      expect(hash0, isNot(equals(hash1)));
    });
  });
}
