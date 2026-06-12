import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/utils/app_snackbar.dart';
import 'package:swoosh/data/csv_statement_parse_result.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

Future<void> showCsvImportFlow(BuildContext context, WidgetRef ref) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv'],
    withData: true,
  );
  if (result == null || result.files.isEmpty || !context.mounted) return;

  final file = result.files.first;
  final content = String.fromCharCodes(file.bytes!);
  final csvService = ref.read(csvImportServiceProvider);

  final parsed = csvService.parseStatement(
    accountId: '',
    csvContent: content,
    fileName: file.name,
  );

  if (parsed.rows.isEmpty) {
    if (context.mounted) {
      showAppSnackBar(context, 'Could not parse any transactions from that CSV');
    }
    return;
  }

  try {
    final account = await _findOrCreateAccount(ref, parsed);
    final rows = parsed.rows
        .map((row) => {...row, 'account_id': account.id})
        .toList();

    var categories = await ref.read(categoriesProvider.future);
    if (categories.isEmpty) {
      await ref.read(categoryRepositoryProvider).seedDefaults();
      categories = await ref.read(categoriesProvider.future);
    }
    final ruleRepo = ref.read(categoryRuleRepositoryProvider);
    await ruleRepo.seedDefaultRules(categories);
    final rules = await ruleRepo.fetchAll();
    final matcher = ref.read(categoryMatcherServiceProvider);

    final categorizedRows = rows.map((row) {
      final categoryId = matcher.match(
        merchant: row['merchant'] as String? ?? row['description'] as String,
        categories: categories,
        rules: rules,
      );
      if (categoryId != null) {
        return {...row, 'category_id': categoryId};
      }
      return row;
    }).toList();

    final txRepo = await ref.read(transactionRepositoryProvider.future);
    final imported = await txRepo.importCsvRows(
      accountId: account.id,
      rows: categorizedRows,
    );

    await _applyStatementBalance(ref, account.id, parsed);

    ref.invalidate(accountsProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(allTransactionsProvider);

    if (context.mounted) {
      showAppSnackBar(
        context,
        'Imported $imported transaction(s) to ${account.name}',
      );
      context.push('/accounts/${account.id}');
    }
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, 'Import failed: $e');
    }
  }
}

Future<Account> _findOrCreateAccount(
  WidgetRef ref,
  CsvStatementParseResult parsed,
) async {
  final accounts = await ref.read(accountsProvider.future);
  final institution = parsed.institution;

  if (institution != null) {
    final existing = accounts.where(
      (account) =>
          (account.source == DataSource.manual || account.source == DataSource.csv) &&
          account.institution?.toLowerCase() == institution.toLowerCase(),
    );
    if (existing.isNotEmpty) return existing.first;
  }

  final balancePence = parsed.closingBalancePence ?? _sumRows(parsed.rows);
  final anchorDate = _latestTransactionDate(parsed.rows) ?? DateTime.now();
  final repo = await ref.read(accountRepositoryProvider.future);

  return repo.create(
    Account(
      id: '',
      userId: '',
      name: institution ?? 'Imported account',
      accountType: AccountType.everyday,
      balancePence: balancePence,
      currency: 'GBP',
      institution: institution,
      source: DataSource.csv,
      balanceAnchorPence: balancePence,
      balanceAnchorDate: anchorDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );
}

Future<void> _applyStatementBalance(
  WidgetRef ref,
  String accountId,
  CsvStatementParseResult parsed,
) async {
  final repo = await ref.read(accountRepositoryProvider.future);

  if (parsed.closingBalancePence != null) {
    final anchorDate = _latestTransactionDate(parsed.rows) ?? DateTime.now();
    await repo.update(accountId, {
      'balance_pence': parsed.closingBalancePence,
      'balance_anchor_pence': parsed.closingBalancePence,
      'balance_anchor_date': anchorDate.toIso8601String().split('T').first,
    });
    return;
  }

  await repo.recomputeBalance(accountId);
}

int _sumRows(List<Map<String, dynamic>> rows) {
  return rows.fold<int>(
    0,
    (sum, row) => sum + (row['amount_pence'] as int? ?? 0),
  );
}

DateTime? _latestTransactionDate(List<Map<String, dynamic>> rows) {
  DateTime? latest;
  for (final row in rows) {
    final raw = row['transaction_date'] as String?;
    if (raw == null) continue;
    final date = DateTime.tryParse(raw);
    if (date == null) continue;
    if (latest == null || date.isAfter(latest)) latest = date;
  }
  return latest;
}
