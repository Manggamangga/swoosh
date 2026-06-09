import 'package:flutter/material.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/widgets/category_icon.dart';
import 'package:swoosh/models/transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.amountPence > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CategoryIcon(
            iconName: 'category',
            color: transaction.categoryColor ?? '#a855f7',
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.merchant ?? transaction.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  transaction.categoryName ?? 'General',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Money.formatSigned(transaction.amountPence),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isIncome ? AppColors.income : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
