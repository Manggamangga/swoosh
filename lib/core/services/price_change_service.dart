import 'package:swoosh/models/recurring_payment.dart';
import 'package:swoosh/models/transaction.dart';

class PriceChangeAlert {
  const PriceChangeAlert({
    required this.recurringPaymentId,
    required this.name,
    required this.oldAmountPence,
    required this.newAmountPence,
    required this.transactionId,
  });

  final String recurringPaymentId;
  final String name;
  final int oldAmountPence;
  final int newAmountPence;
  final String transactionId;
}

class PriceChangeService {
  List<PriceChangeAlert> detect({
    required List<RecurringPayment> recurring,
    required List<Transaction> transactions,
  }) {
    final alerts = <PriceChangeAlert>[];

    for (final payment in recurring) {
      if (payment.amountPence >= 0) continue;

      final paymentName = payment.name.toLowerCase();
      for (final transaction in transactions) {
        if (transaction.amountPence >= 0) continue;

        final merchant = (transaction.merchant ?? transaction.description)
            .toLowerCase();
        if (!merchant.contains(paymentName) &&
            !paymentName.contains(merchant)) {
          continue;
        }

        if (transaction.amountPence.abs() != payment.amountPence.abs()) {
          alerts.add(
            PriceChangeAlert(
              recurringPaymentId: payment.id,
              name: payment.name,
              oldAmountPence: payment.amountPence,
              newAmountPence: transaction.amountPence,
              transactionId: transaction.id,
            ),
          );
          break;
        }
      }
    }

    return alerts;
  }
}
