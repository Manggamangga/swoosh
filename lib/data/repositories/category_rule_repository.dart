import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/models/category.dart';
import 'package:swoosh/models/category_rule.dart';

const seededMerchantKeywords = <String, String>{
  'TESCO': 'Groceries',
  'SAINSBURY': 'Groceries',
  'ASDA': 'Groceries',
  'ALDI': 'Groceries',
  'LIDL': 'Groceries',
  'MORRISONS': 'Groceries',
  'WAITROSE': 'Groceries',
  'NETFLIX': 'Entertainment',
  'SPOTIFY': 'Entertainment',
  'DISNEY': 'Entertainment',
  'AMAZON PRIME': 'Entertainment',
  'OCTOPUS': 'Bills',
  'BRITISH GAS': 'Bills',
  'BT GROUP': 'Bills',
  'VODAFONE': 'Bills',
  'EE LIMITED': 'Bills',
  'UBER': 'Transport',
  'TRAINLINE': 'Transport',
  'TFL': 'Transport',
};

class CategoryRuleRepository {
  CategoryRuleRepository(this._client);

  final SupabaseClient _client;

  Future<List<CategoryRule>> fetchAll() async {
    final data = await _client.from('category_rules').select().order('matcher');
    return (data as List).map((e) => CategoryRule.fromJson(e)).toList();
  }

  Future<void> upsertLearnedRule({
    required String matcher,
    required String categoryId,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('category_rules').upsert(
      {
        'user_id': userId,
        'matcher': matcher.toLowerCase().trim(),
        'matcher_type': 'merchant',
        'category_id': categoryId,
        'source': 'learned',
      },
      onConflict: 'user_id,matcher_type,matcher',
    );
  }

  Future<void> seedDefaultRules(List<Category> categories) async {
    final userId = _client.auth.currentUser!.id;
    final existing = await fetchAll();
    if (existing.isNotEmpty) return;

    final byName = {
      for (final category in categories) category.name.toLowerCase(): category.id,
    };

    final rows = <Map<String, dynamic>>[];
    for (final entry in seededMerchantKeywords.entries) {
      final categoryId = byName[entry.value.toLowerCase()];
      if (categoryId == null) continue;
      rows.add({
        'user_id': userId,
        'matcher': entry.key.toLowerCase(),
        'matcher_type': 'keyword',
        'category_id': categoryId,
        'source': 'seeded',
      });
    }

    if (rows.isEmpty) return;
    await _client.from('category_rules').upsert(
      rows,
      onConflict: 'user_id,matcher_type,matcher',
    );
  }
}
