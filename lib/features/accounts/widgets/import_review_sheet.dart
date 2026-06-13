import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/data/import/adapters/generic_csv_adapter.dart';

Future<bool> showImportReviewSheet(
  BuildContext context,
  GenericCsvPreview preview,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final bottomPad = ViewInsets.bottomClearance(sheetContext);
      final dateFormat = DateFormat('d MMM yyyy');

      return Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Review import',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              preview.accountName,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (preview.errorMessage != null) ...[
              SwooshCard(
                child: Text(
                  preview.errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SwooshCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${preview.statement.transactions.length} transactions from ${preview.totalDataRows} rows',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (preview.balanceFieldName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Balance column: ${preview.balanceFieldName}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (preview.statement.closingBalancePence != null)
                      Text(
                        'Closing balance: ${Money.format(preview.statement.closingBalancePence!)}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Column mapping',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...preview.columnMapping.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${entry.key}: ${entry.value ?? 'Not found'}',
                        style: TextStyle(
                          color: entry.value == null
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (preview.sampleTransactions.isNotEmpty) ...[
              const SizedBox(height: 12),
              SwooshCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sample rows',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ...preview.sampleTransactions.map(
                      (tx) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    dateFormat.format(tx.date),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Money.formatSigned(tx.amountPence),
                              style: TextStyle(
                                color: tx.amountPence >= 0
                                    ? AppColors.income
                                    : AppColors.spending,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: preview.hasRequiredColumns &&
                            preview.statement.transactions.isNotEmpty
                        ? () => Navigator.pop(sheetContext, true)
                        : null,
                    child: const Text('Import'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  return result ?? false;
}
