import 'package:flutter/material.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/spacing.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/models/account.dart';

class AccountRow extends StatelessWidget {
  const AccountRow({
    super.key,
    required this.account,
    this.onTap,
    this.heroTag,
    this.showDivider = false,
  });

  final Account account;
  final VoidCallback? onTap;
  final String? heroTag;
  final bool showDivider;

  int get _displayBalancePence => switch (account.accountType) {
        AccountType.credit => -account.balancePence.abs(),
        _ => account.balancePence,
      };

  Color get _accent {
    switch (account.accountType) {
      case AccountType.everyday:
        return AppColors.everyday;
      case AccountType.savings:
        return AppColors.savings;
      case AccountType.credit:
        return AppColors.credit;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: AppSpacing.iconSize,
      height: AppSpacing.iconSize,
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.account_balance, color: _accent, size: 22),
    );

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.listItemVertical,
                horizontal: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  heroTag != null
                      ? Hero(tag: heroTag!, child: icon)
                      : icon,
                  const SizedBox(width: AppSpacing.iconGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: AppTextStyles.tileTitle(context),
                        ),
                        if (account.institution != null)
                          Text(
                            account.institution!,
                            style: AppTextStyles.tileSubtitle(context),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    Money.format(
                      _displayBalancePence,
                      currency: account.currency,
                    ),
                    style: AppTextStyles.tileTitle(context).copyWith(color: _accent),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
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
