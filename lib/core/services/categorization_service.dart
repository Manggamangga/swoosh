import 'package:swoosh/core/services/category_matcher_service.dart';
import 'package:swoosh/data/repositories/category_repository.dart';
import 'package:swoosh/data/repositories/category_rule_repository.dart';
import 'package:swoosh/data/repositories/transaction_repository.dart';
import 'package:swoosh/models/category.dart';
import 'package:swoosh/models/category_rule.dart';
import 'package:swoosh/models/transaction.dart';

class CategorizationService {
  CategorizationService({
    required CategoryRepository categoryRepository,
    required CategoryRuleRepository ruleRepository,
    required TransactionRepository transactionRepository,
    required CategoryMatcherService matcher,
  })  : _categoryRepository = categoryRepository,
        _ruleRepository = ruleRepository,
        _transactionRepository = transactionRepository,
        _matcher = matcher;

  final CategoryRepository _categoryRepository;
  final CategoryRuleRepository _ruleRepository;
  final TransactionRepository _transactionRepository;
  final CategoryMatcherService _matcher;

  Future<int> retroactivelyCategorize() async {
    final categories = await _categoryRepository.fetchAll();
    if (categories.isEmpty) {
      await _categoryRepository.seedDefaults();
    }
    final resolvedCategories = categories.isEmpty
        ? await _categoryRepository.fetchAll()
        : categories;
    await _ruleRepository.seedDefaultRules(resolvedCategories);
    final rules = await _ruleRepository.fetchAll();
    final uncategorized = await _transactionRepository.fetchUncategorized();

    var updated = 0;
    for (final transaction in uncategorized) {
      final categoryId = _matcher.match(
        merchant: transaction.merchant ?? transaction.description,
        categories: resolvedCategories,
        rules: rules,
      );
      if (categoryId == null || categoryId == transaction.categoryId) continue;
      await _transactionRepository.updateCategory(
        transactionId: transaction.id,
        categoryId: categoryId,
      );
      updated++;
    }
    return updated;
  }

  Future<String?> categoryForMerchant({
    required String merchant,
    required List<Category> categories,
    required List<CategoryRule> rules,
  }) {
    return Future.value(
      _matcher.match(
        merchant: merchant,
        categories: categories,
        rules: rules,
      ),
    );
  }

  Future<void> learnFromCorrection({
    required Transaction transaction,
    required String categoryId,
  }) async {
    final merchant = (transaction.merchant ?? transaction.description).trim();
    if (merchant.isEmpty) return;
    await _ruleRepository.upsertLearnedRule(
      matcher: merchant,
      categoryId: categoryId,
    );
  }
}
