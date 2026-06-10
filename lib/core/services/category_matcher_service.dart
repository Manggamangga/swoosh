import 'package:swoosh/models/category.dart';
import 'package:swoosh/models/category_rule.dart';

const monzoCategoryToName = <String, String>{
  'groceries': 'Groceries',
  'eating_out': 'Eating out',
  'shopping': 'Shopping',
  'transport': 'Transport',
  'bills': 'Bills',
  'entertainment': 'Entertainment',
  'holidays': 'Holidays',
  'personal_care': 'Personal care',
  'income': 'Income',
  'general': 'General',
  'expenses': 'General',
  'cash': 'General',
  'transfers': 'Transfer',
  'savings': 'Savings',
};

class CategoryMatcherService {
  String? match({
    required String merchant,
    required List<Category> categories,
    required List<CategoryRule> rules,
    String? monzoCategory,
  }) {
    final categoriesByName = {
      for (final category in categories) category.name.toLowerCase(): category.id,
    };
    final merchantKey = merchant.toLowerCase().trim();

    for (final rule in rules) {
      if (rule.matcherType == CategoryRuleMatcherType.monzoCategory) continue;
      final matcher = rule.matcher.toLowerCase().trim();
      if (merchantKey.contains(matcher) || matcher.contains(merchantKey)) {
        return rule.categoryId;
      }
    }

    if (monzoCategory != null) {
      for (final rule in rules) {
        if (rule.matcherType != CategoryRuleMatcherType.monzoCategory) continue;
        if (rule.matcher.toLowerCase() == monzoCategory.toLowerCase()) {
          return rule.categoryId;
        }
      }

      final mappedName = monzoCategoryToName[monzoCategory.toLowerCase()];
      if (mappedName != null) {
        return categoriesByName[mappedName.toLowerCase()];
      }
    }

    return categoriesByName['general'];
  }
}
