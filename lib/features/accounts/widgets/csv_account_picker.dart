import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/providers/data_providers.dart';

Future<void> showCsvAccountPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return Consumer(
        builder: (context, ref, _) {
          final accountsAsync = ref.watch(accountsProvider);
          final bottomPad = ViewInsets.bottomClearance(context);

          return accountsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: $error'),
            ),
            data: (accounts) {
              final importable = accounts
                  .where(
                    (account) =>
                        account.source == DataSource.manual ||
                        account.source == DataSource.csv,
                  )
                  .toList();

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Import CSV',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Which account is this statement for?',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    for (final account in importable) ...[
                      SwooshCard(
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/accounts/${account.id}/import');
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
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
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SwooshCard(
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/accounts/add?continueImport=1');
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: AppColors.primary),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'New account…',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}
