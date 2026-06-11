import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/models/recurring_payment.dart';

class UpcomingBillsCard extends StatelessWidget {
  const UpcomingBillsCard({
    super.key,
    required this.payments,
    required this.monthTotalPence,
  });

  final List<RecurringPayment> payments;
  final int monthTotalPence;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) return const SizedBox.shrink();

    final preview = payments.take(4).toList();
    final dateFormat = DateFormat('d MMM');

    return SwooshCard(
      onTap: () => context.push('/planning/recurring'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upcoming bills',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                '${Money.format(monthTotalPence)} due this month',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...preview.map(
            (payment) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(payment.nextDate),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Money.format(payment.amountPence),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.spending,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (payments.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${payments.length - 4} more',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
