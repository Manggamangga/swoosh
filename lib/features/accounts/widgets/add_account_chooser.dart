import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/sheet_navigation.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/features/accounts/widgets/csv_import_flow.dart';

Future<void> showAddAccountChooser(BuildContext context, WidgetRef ref) {
  final router = GoRouter.of(context);
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
              'Add account',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect Monzo automatically or add other banks manually or via CSV.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            SwooshCard(
              onTap: () {
                Navigator.pop(sheetContext);
                pushAfterSheetDismiss(router, '/connect-bank');
              },
              child: const Row(
                children: [
                  Icon(Icons.account_balance, color: AppColors.primary),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connect Monzo',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Automatic sync — balances and transactions',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwooshCard(
              onTap: () {
                Navigator.pop(sheetContext);
                pushAfterSheetDismiss(router, '/accounts/add');
              },
              child: const Row(
                children: [
                  Icon(Icons.edit_outlined, color: AppColors.everyday),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add manually',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Barclays, Wise, Moneybox, or any account',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwooshCard(
              onTap: () {
                Navigator.pop(sheetContext);
                showCsvImportFlow(parentContext, ref);
              },
              child: const Row(
                children: [
                  Icon(Icons.upload_file, color: AppColors.everyday),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import CSV',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Pick a statement — bank and balance inferred automatically',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
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
}
