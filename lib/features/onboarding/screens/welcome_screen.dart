import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/spacing.dart';
import 'package:swoosh/core/utils/haptics.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/features/accounts/widgets/csv_import_flow.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/onboarding_provider.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _completeAndGo(BuildContext context, WidgetRef ref, String path) async {
    await ref.read(onboardingCompletedProvider.notifier).markCompleted();
    if (context.mounted) context.go(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Welcome to Swoosh',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Import a bank statement to see balances, spending, and insights — all on your device.',
                style: AppTextStyles.bodyMuted(context),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              _FeatureRow(
                icon: Icons.upload_file_outlined,
                title: 'Statement import',
                subtitle: 'Barclays, Wise, Amex — CSV or PDF',
              ),
              const SizedBox(height: AppSpacing.lg),
              _FeatureRow(
                icon: Icons.pie_chart_outline,
                title: 'Spending breakdown',
                subtitle: 'Categories, budgets, and month-over-month trends',
              ),
              const SizedBox(height: AppSpacing.lg),
              _FeatureRow(
                icon: Icons.event_repeat,
                title: 'Recurring detection',
                subtitle: 'Spot subscriptions and bills automatically',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    AppHaptics.light();
                    await ref.read(onboardingCompletedProvider.notifier).markCompleted();
                    if (!context.mounted) return;
                    await showCsvImportFlow(context, ref);
                    ref.invalidate(accountsProvider);
                    if (context.mounted) context.go('/');
                  },
                  child: const Text('Import a statement'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () {
                  AppHaptics.light();
                  _completeAndGo(context, ref, '/');
                },
                child: const Text('Skip for now'),
              ),
              SizedBox(height: ViewInsets.bottomClearance(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.captionMuted(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
