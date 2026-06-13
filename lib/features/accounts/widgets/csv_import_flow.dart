import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/utils/app_snackbar.dart';
import 'package:swoosh/core/utils/haptics.dart';
import 'package:swoosh/data/import/adapters/barclays_pdf_adapter.dart';
import 'package:swoosh/data/import/adapters/generic_csv_adapter.dart';
import 'package:swoosh/data/import/parsed_statement.dart';
import 'package:swoosh/features/accounts/screens/account_detail_screen.dart';
import 'package:swoosh/features/accounts/widgets/import_review_sheet.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

Future<String?> emptyImportGuidance({
  required ParsedStatement parsed,
  required Uint8List bytes,
  required String filename,
}) async {
  if (parsed.transactions.isNotEmpty) return null;

  if (BarclaysPdfAdapter.isPdfFile(filename, bytes)) {
    final text = BarclaysPdfAdapter().extractText(bytes).toLowerCase();
    if (text.contains('barclays') &&
        (text.contains('no transaction found') ||
            text.contains('pending debit card'))) {
      return 'This looks like a live transactions view, not a statement. '
          'Export a full statement with a settled transaction table.';
    }
  }

  return 'Could not parse any transactions from that file. '
      'Try a full bank statement export (CSV or PDF).';
}

Future<void> showCsvImportFlow(
  BuildContext context,
  WidgetRef ref, {
  String? accountId,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv', 'pdf'],
    withData: true,
  );

  if (result == null || result.files.isEmpty || !context.mounted) return;

  final file = result.files.first;
  final bytes = file.bytes;
  if (bytes == null) {
    if (context.mounted) {
      showAppSnackBar(context, 'Could not read file contents');
    }
    return;
  }

  try {
    final importService = await ref.read(importServiceProvider.future);
    final detector = ref.read(statementDetectorProvider);
    final adapter = detector.detect(bytes, file.name);
    late ParsedStatement parsed;

    if (adapter is GenericCsvAdapter) {
      final preview = adapter.preview(bytes, file.name);

      if (!context.mounted) return;
      final confirmed = await showImportReviewSheet(context, preview);
      if (!confirmed) return;

      parsed = importService.classifyStatement(preview.statement);
    } else {
      parsed = await importService.parse(bytes, file.name);
    }

    if (parsed.transactions.isEmpty) {
      if (!context.mounted) return;
      final guidance = await emptyImportGuidance(
        parsed: parsed,
        bytes: bytes,
        filename: file.name,
      );
      if (!context.mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No transactions found'),
            content: Text(guidance ?? 'Could not parse any transactions.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      return;
    }

    final Account account;
    if (accountId != null) {
      final accounts = await ref.read(accountsProvider.future);
      final existing = accounts.where((a) => a.id == accountId).firstOrNull;
      if (existing == null) {
        if (context.mounted) {
          showAppSnackBar(context, 'Account not found');
        }
        return;
      }
      account = existing;
    } else {
      account = await importService.findOrCreateAccount(
        statement: parsed,
        existingAccounts: await ref.read(accountsProvider.future),
      );
    }

    final importResult = await importService.import(
      statement: parsed,
      account: account,
    );

    ref.invalidate(accountsProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(netWorthProvider);
    if (accountId != null) {
      ref.invalidate(accountTransactionsProvider(accountId));
    }

    if (context.mounted) {
      AppHaptics.success();
      final skipped = importResult.skippedCount;
      final imported = importResult.importedCount;
      final message = skipped > 0
          ? 'Added $imported new, skipped $skipped duplicate(s)'
          : 'Imported $imported transaction(s) to ${importResult.account.name}';
      showAppSnackBar(context, message);
      context.push('/accounts/${importResult.account.id}');
    }
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, 'Import failed: $e');
    }
  }
}
