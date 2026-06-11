import 'package:flutter/material.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/models/account.dart';

class AccountRow extends StatelessWidget {
  const AccountRow({
    super.key,
    required this.account,
    this.onTap,
    this.heroTag,
  });

  final Account account;
  final VoidCallback? onTap;
  final String? heroTag;

  Color get _accent {
    switch (account.accountType) {
      case AccountType.everyday:
        return AppColors.everyday;
      case AccountType.savings:
        return AppColors.savings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.account_balance, color: _accent, size: 22),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              heroTag != null
                  ? Hero(tag: heroTag!, child: icon)
                  : icon,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (account.institution != null)
                      Text(
                        account.institution!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                Money.format(account.balancePence, currency: account.currency),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: _accent,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
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
    );
  }
}
