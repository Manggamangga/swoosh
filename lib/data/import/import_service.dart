import 'dart:typed_data';

import 'package:swoosh/core/services/category_matcher_service.dart';
import 'package:swoosh/core/services/transfer_noise_classifier.dart';
import 'package:swoosh/core/utils/dedupe.dart';
import 'package:swoosh/data/import/parsed_statement.dart';
import 'package:swoosh/data/import/statement_detector.dart';
import 'package:swoosh/data/repositories/account_repository.dart';
import 'package:swoosh/data/repositories/category_repository.dart';
import 'package:swoosh/data/repositories/category_rule_repository.dart';
import 'package:swoosh/data/repositories/transaction_repository.dart';
import 'package:swoosh/data/import/csv_parse_utils.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/category.dart';
import 'package:swoosh/models/category_rule.dart';

class ImportResult {
  const ImportResult({
    required this.account,
    required this.importedCount,
    required this.skippedCount,
    required this.totalRows,
  });

  final Account account;
  final int importedCount;
  final int skippedCount;
  final int totalRows;
}

class ImportService {
  ImportService({
    required StatementDetector detector,
    required AccountRepository accountRepository,
    required TransactionRepository transactionRepository,
    required CategoryRepository categoryRepository,
    required CategoryRuleRepository categoryRuleRepository,
    required CategoryMatcherService categoryMatcher,
    TransferNoiseClassifier? transferNoiseClassifier,
  })  : _detector = detector,
        _accountRepository = accountRepository,
        _transactionRepository = transactionRepository,
        _categoryRepository = categoryRepository,
        _categoryRuleRepository = categoryRuleRepository,
        _categoryMatcher = categoryMatcher,
        _transferNoiseClassifier =
            transferNoiseClassifier ?? TransferNoiseClassifier();

  final StatementDetector _detector;
  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;
  final CategoryRepository _categoryRepository;
  final CategoryRuleRepository _categoryRuleRepository;
  final CategoryMatcherService _categoryMatcher;
  final TransferNoiseClassifier _transferNoiseClassifier;

  ParsedStatement classifyStatement(ParsedStatement statement) {
    return _applyTransferClassification(statement);
  }

  Future<ParsedStatement> parse(Uint8List bytes, String filename) async {
    final adapter = _detector.detect(bytes, filename);
    final statement = await adapter.parse(bytes, filename);
    return _applyTransferClassification(statement);
  }

  ParsedStatement _applyTransferClassification(ParsedStatement statement) {
    final classifiedTransactions = statement.transactions.map((tx) {
      final classification = _transferNoiseClassifier.classifyTransaction(
        description: tx.description,
        amountPence: tx.amountPence,
        metadata: tx.metadata,
      );

      if (!classification.isExcluded && !tx.excludeFromAnalytics) {
        return tx;
      }

      return tx.copyWith(excludeFromAnalytics: true);
    }).toList();

    return ParsedStatement(
      institution: statement.institution,
      accountIdentifier: statement.accountIdentifier,
      transactions: classifiedTransactions,
      closingBalancePence: statement.closingBalancePence,
      currency: statement.currency,
      accountType: statement.accountType,
      requiresImportReview: statement.requiresImportReview,
      columnMapping: statement.columnMapping,
    );
  }

  Future<Account> findOrCreateAccount({
    required ParsedStatement statement,
    required List<Account> existingAccounts,
    int? balancePence,
  }) async {
    final existing = _findExistingAccount(existingAccounts, statement);
    if (existing != null) return existing;

    final anchorDate = _latestTransactionDate(statement) ?? DateTime.now();
    final resolvedBalance = balancePence ??
        statement.closingBalancePence ??
        _sumTransactions(statement);

    return _accountRepository.create(
      Account(
        id: '',
        userId: '',
        name: _defaultAccountName(statement),
        accountType: statement.accountType,
        balancePence: resolvedBalance,
        currency: statement.currency,
        institution: statement.institution,
        source: DataSource.csv,
        externalRef: statement.accountIdentifier != null
            ? normalizeAccountIdentifier(statement.accountIdentifier!)
            : null,
        balanceAnchorPence: resolvedBalance,
        balanceAnchorDate: anchorDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<ImportResult> import({
    required ParsedStatement statement,
    required Account account,
    int? userBalancePence,
  }) async {
    if (statement.transactions.isEmpty) {
      return ImportResult(
        account: account,
        importedCount: 0,
        skippedCount: 0,
        totalRows: 0,
      );
    }

    final categories = await _ensureCategories();
    final rules = await _ensureRules(categories);
    final ordinals = computeOrdinalMap(statement.transactions);

    final rows = statement.transactions.map((tx) {
      final categoryId = _categoryMatcher.match(
        merchant: tx.merchant ?? tx.description,
        categories: categories,
        rules: rules,
      );

      final row = <String, dynamic>{
        'account_id': account.id,
        'transaction_date': tx.date.toIso8601String().split('T').first,
        'amount_pence': tx.amountPence,
        'currency': tx.currency,
        'description': tx.description,
        'merchant': tx.merchant ?? tx.description,
        'source': DataSource.csv.name,
        'dedupe_hash': buildDedupeHash(
          accountId: account.id,
          date: tx.date,
          amountPence: tx.amountPence,
          description: tx.description,
          providerTxnId: tx.providerTxnId,
          ordinal: ordinals[tx] ?? 0,
        ),
        'exclude_from_analytics': tx.excludeFromAnalytics,
      };

      if (tx.providerTxnId != null && tx.providerTxnId!.isNotEmpty) {
        row['external_ref'] = tx.providerTxnId;
      }

      if (categoryId != null) {
        row['category_id'] = categoryId;
      }

      return row;
    }).toList();

    final importCounts = await _transactionRepository.importCsvRows(
      accountId: account.id,
      rows: rows,
    );

    await _applyBalanceAnchor(
      accountId: account.id,
      statement: statement,
      userBalancePence: userBalancePence,
    );

    final updatedAccount =
        await _accountRepository.fetchById(account.id) ?? account;

    return ImportResult(
      account: updatedAccount,
      importedCount: importCounts.imported,
      skippedCount: importCounts.skipped,
      totalRows: rows.length,
    );
  }

  Account? _findExistingAccount(
    List<Account> accounts,
    ParsedStatement statement,
  ) {
    if (statement.accountIdentifier != null) {
      final normalized =
          normalizeAccountIdentifier(statement.accountIdentifier!);
      final matches = accounts.where(
        (account) =>
            account.externalRef != null &&
            normalizeAccountIdentifier(account.externalRef!) == normalized,
      );
      if (matches.isNotEmpty) return matches.first;
    }

    if (statement.institution.isNotEmpty) {
      final matches = accounts.where(
        (account) =>
            account.source == DataSource.csv &&
            account.institution?.toLowerCase() ==
                statement.institution.toLowerCase() &&
            statement.accountIdentifier == null,
      );
      if (matches.isNotEmpty) return matches.first;
    }

    return null;
  }

  Future<void> _applyBalanceAnchor({
    required String accountId,
    required ParsedStatement statement,
    int? userBalancePence,
  }) async {
    final account = await _accountRepository.fetchById(accountId);
    if (account == null) return;

    final anchorDate = _latestTransactionDate(statement) ?? DateTime.now();
    final anchorDateStr = anchorDate.toIso8601String().split('T').first;
    final anchorDay = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);

    if (userBalancePence != null) {
      final currentAnchor = account.balanceAnchorDate;
      final shouldAdvance = currentAnchor == null ||
          !anchorDay.isBefore(DateTime(
            currentAnchor.year,
            currentAnchor.month,
            currentAnchor.day,
          ));

      if (shouldAdvance) {
        await _accountRepository.update(accountId, {
          'balance_pence': userBalancePence,
          'balance_anchor_pence': userBalancePence,
          'balance_anchor_date': anchorDateStr,
        });
        return;
      }

      await _accountRepository.recomputeBalance(accountId);
      return;
    }

    if (statement.closingBalancePence != null) {
      final currentAnchor = account.balanceAnchorDate;
      final shouldAdvance = currentAnchor == null ||
          !anchorDay.isBefore(DateTime(
            currentAnchor.year,
            currentAnchor.month,
            currentAnchor.day,
          ));

      if (shouldAdvance) {
        await _accountRepository.update(accountId, {
          'balance_pence': statement.closingBalancePence,
          'balance_anchor_pence': statement.closingBalancePence,
          'balance_anchor_date': anchorDateStr,
        });
        return;
      }

      await _accountRepository.recomputeBalance(accountId);
      return;
    }

    await _accountRepository.recomputeBalance(accountId);
  }

  Future<List<Category>> _ensureCategories() async {
    var categories = await _categoryRepository.fetchAll();
    if (categories.isEmpty) {
      await _categoryRepository.seedDefaults();
      categories = await _categoryRepository.fetchAll();
    }
    return categories;
  }

  Future<List<CategoryRule>> _ensureRules(List<Category> categories) async {
    await _categoryRuleRepository.seedDefaultRules(categories);
    return _categoryRuleRepository.fetchAll();
  }

  String _defaultAccountName(ParsedStatement statement) {
    return statement.suggestedAccountName;
  }

  DateTime? _latestTransactionDate(ParsedStatement statement) {
    DateTime? latest;
    for (final tx in statement.transactions) {
      if (latest == null || tx.date.isAfter(latest)) {
        latest = tx.date;
      }
    }
    return latest;
  }

  int _sumTransactions(ParsedStatement statement) {
    return statement.transactions.fold<int>(
      0,
      (sum, tx) => sum + tx.amountPence,
    );
  }
}
