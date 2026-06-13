import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/core/services/transfer_noise_classifier.dart';

void main() {
  late TransferNoiseClassifier classifier;

  setUp(() {
    classifier = TransferNoiseClassifier();
  });

  group('TransferNoiseClassifier', () {
    test('excludes Wise noise detail types', () {
      for (final type in [
        'CONVERSION',
        'INVESTMENT_TRADE_ORDER',
        'ACCRUAL_CHARGE',
        'MONEY_ADDED',
      ]) {
        final result = classifier.classifyTransaction(
          description: 'Some Wise row',
          amountPence: -1000,
          metadata: {'transaction_details_type': type},
        );
        expect(result.isExcluded, isTrue, reason: type);
        expect(result.reason, contains(type));
      }
    });

    test('excludes own-account transfer descriptions', () {
      expect(
        classifier
            .classifyTransaction(
              description: 'Sent money to Sean Loh',
              amountPence: -100000,
            )
            .isExcluded,
        isTrue,
      );
      expect(
        classifier
            .classifyTransaction(
              description: 'Topped up account',
              amountPence: 50000,
            )
            .isExcluded,
        isTrue,
      );
      expect(
        classifier
            .classifyTransaction(
              description:
                  'Received money from LOH S with reference SEAN WISE',
              amountPence: 50000,
            )
            .isExcluded,
        isTrue,
      );
    });

    test('keeps genuine income from other people', () {
      final result = classifier.classifyTransaction(
        description: 'Received money from Jeslyn Cheong with reference Dinner',
        amountPence: 25000,
        metadata: const {'transaction_details_type': 'DEPOSIT'},
      );

      expect(result.isExcluded, isFalse);
      expect(result.isTransfer, isFalse);
    });

    test('keeps ordinary card spend', () {
      final result = classifier.classifyTransaction(
        description: 'Card payment to TESCO STORES',
        amountPence: -4599,
        metadata: const {
          'transaction_type': 'CARD',
          'transaction_details_type': 'CARD_PAYMENT',
        },
      );

      expect(result.isExcluded, isFalse);
    });

    test('marks transfers as isTransfer when appropriate', () {
      final conversion = classifier.classifyTransaction(
        description: 'Converted GBP to USD',
        amountPence: -50000,
        metadata: const {
          'transaction_type': 'CONVERSION',
          'transaction_details_type': 'CONVERSION',
        },
      );
      expect(conversion.isTransfer, isTrue);

      final ownTransfer = classifier.classifyTransaction(
        description: 'Sent money to Sean Loh',
        amountPence: -100000,
        metadata: const {'transaction_type': 'TRANSFER'},
      );
      expect(ownTransfer.isTransfer, isTrue);
    });
  });
}
