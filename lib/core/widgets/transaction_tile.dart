import 'package:flutter/material.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/spacing.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/widgets/category_icon.dart';
import 'package:swoosh/models/transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.showExcludedBadge = false,
    this.showDivider = false,
  });

  final Transaction transaction;
  final bool showExcludedBadge;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.amountPence > 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.listItemVertical),
          child: Row(
            children: [
              CategoryIcon(
                iconName: 'category',
                color: transaction.categoryColor ?? '#A855F7',
              ),
              const SizedBox(width: AppSpacing.iconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.merchant ?? transaction.description,
                      style: AppTextStyles.tileTitle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      transaction.categoryName ?? 'General',
                      style: AppTextStyles.tileSubtitle(context),
                    ),
                    if (showExcludedBadge && transaction.excludeFromAnalytics)
                      Text(
                        'Excluded from analytics',
                        style: AppTextStyles.captionMuted(context),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                Money.formatSigned(transaction.amountPence),
                style: AppTextStyles.tileTitle(context).copyWith(
                  color: isIncome ? AppColors.income : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: 0.6),
          ),
      ],
    );
  }
}
