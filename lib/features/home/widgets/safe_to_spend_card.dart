import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/core/services/safe_to_spend_service.dart';

class SafeToSpendCard extends StatelessWidget {
  const SafeToSpendCard({super.key, required this.result});

  final SafeToSpendResult result;

  @override
  Widget build(BuildContext context) {
    final incomeLabel = result.nextIncomeDate != null
        ? DateFormat('d MMM').format(result.nextIncomeDate!)
        : 'next payday';

    return SwooshCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Safe to spend',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            Money.format(result.amountPence),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: result.amountPence >= 0
                      ? AppColors.income
                      : AppColors.error,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Until $incomeLabel · after bills & budgets',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
