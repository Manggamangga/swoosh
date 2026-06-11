import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swoosh/core/services/price_change_service.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

class PriceChangeAlertCard extends ConsumerWidget {
  const PriceChangeAlertCard({super.key, required this.alert});

  final PriceChangeAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwooshCard(
      child: Row(
        children: [
          const Icon(Icons.trending_up, color: AppColors.spending),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${Money.format(alert.oldAmountPence)} → ${Money.format(alert.newAmountPence)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _updateRecurring(context, ref),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRecurring(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(recurringRepositoryProvider);
    await repo.update(alert.recurringPaymentId, {
      'amount_pence': alert.newAmountPence,
    });
    ref.invalidate(recurringProvider);
    ref.invalidate(priceChangeAlertsProvider);
    ref.invalidate(safeToSpendProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${alert.name}')),
      );
    }
  }
}
