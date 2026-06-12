import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/features/accounts/screens/account_detail_screen.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends ConsumerState<CsvImportScreen> {
  String? _fileName;
  int? _rowCount;
  bool _loading = false;
  String? _result;

  Future<void> _pickAndImport() async {
    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      _fileName = file.name;
      final content = String.fromCharCodes(file.bytes!);

      final csvService = ref.read(csvImportServiceProvider);
      final statement = csvService.parseStatement(
        accountId: widget.accountId,
        csvContent: content,
        fileName: file.name,
      );
      var rows = statement.rows;
      _rowCount = rows.length;

      var categories = await ref.read(categoriesProvider.future);
      if (categories.isEmpty) {
        await ref.read(categoryRepositoryProvider).seedDefaults();
        categories = await ref.read(categoriesProvider.future);
      }
      final ruleRepo = ref.read(categoryRuleRepositoryProvider);
      await ruleRepo.seedDefaultRules(categories);
      final rules = await ruleRepo.fetchAll();
      final matcher = ref.read(categoryMatcherServiceProvider);

      rows = rows.map((row) {
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
        accountId: widget.accountId,
        rows: rows,
      );

      if (statement.closingBalancePence != null) {
        final accountRepo = await ref.read(accountRepositoryProvider.future);
        final latestDate = rows
            .map((row) => DateTime.tryParse(row['transaction_date'] as String? ?? ''))
            .whereType<DateTime>()
            .fold<DateTime?>(
              null,
              (latest, date) =>
                  latest == null || date.isAfter(latest) ? date : latest,
            );
        await accountRepo.update(widget.accountId, {
          'balance_pence': statement.closingBalancePence,
          'balance_anchor_pence': statement.closingBalancePence,
          'balance_anchor_date':
              (latestDate ?? DateTime.now()).toIso8601String().split('T').first,
        });
      }

      ref.invalidate(transactionsProvider);
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(accountTransactionsProvider(widget.accountId));
      setState(() => _result = 'Imported $imported of ${rows.length} rows');
    } catch (e) {
      setState(() => _result = 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import CSV')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Import a bank statement CSV. Duplicate transactions are automatically skipped.',
            ),
            const SizedBox(height: 24),
            if (_fileName != null) ...[
              Text('File: $_fileName'),
              if (_rowCount != null) Text('Rows parsed: $_rowCount'),
              const SizedBox(height: 12),
            ],
            if (_result != null) ...[
              Text(_result!),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              onPressed: _loading ? null : _pickAndImport,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: const Text('Select CSV file'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
