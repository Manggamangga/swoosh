import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/core/utils/dedupe.dart';

void main() {
  test('buildDedupeHash is deterministic', () {
    final hash1 = buildDedupeHash(
      accountId: 'acc-1',
      date: DateTime(2026, 6, 9),
      amountPence: -9400,
      description: 'Glenn Magsino',
    );
    final hash2 = buildDedupeHash(
      accountId: 'acc-1',
      date: DateTime(2026, 6, 9),
      amountPence: -9400,
      description: 'glenn magsino',
    );
    expect(hash1, hash2);
  });

  test('buildDedupeHash differs for different amounts', () {
    final hash1 = buildDedupeHash(
      accountId: 'acc-1',
      date: DateTime(2026, 6, 9),
      amountPence: -9400,
      description: 'Test',
    );
    final hash2 = buildDedupeHash(
      accountId: 'acc-1',
      date: DateTime(2026, 6, 9),
      amountPence: -9500,
      description: 'Test',
    );
    expect(hash1, isNot(hash2));
  });
}
