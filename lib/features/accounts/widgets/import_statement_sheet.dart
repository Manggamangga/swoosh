import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/features/accounts/widgets/csv_import_flow.dart';

Future<void> showImportStatementSheet(
  BuildContext context,
  WidgetRef ref, {
  String? accountId,
}) {
  final parentContext = context;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final bottomPad = ViewInsets.bottomClearance(sheetContext);
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Import a statement',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add an account by importing a bank statement. Swoosh detects the bank automatically and skips duplicates on re-import.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            SwooshCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supported',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const _SupportRow(label: 'Barclays', detail: 'CSV or PDF statement'),
                  const _SupportRow(label: 'Wise', detail: 'CSV or PDF statement'),
                  const _SupportRow(label: 'Amex', detail: 'Activity CSV'),
                  const _SupportRow(label: 'Other banks', detail: 'Best-effort CSV'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                showCsvImportFlow(
                  parentContext,
                  ref,
                  accountId: accountId,
                );
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose file'),
            ),
          ],
        ),
      );
    },
  );
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                children: [
                  TextSpan(
                    text: '$label — ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: detail,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
