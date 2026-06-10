import 'package:equatable/equatable.dart';

enum CategoryRuleMatcherType { merchant, monzoCategory, keyword }

enum CategoryRuleSource { seeded, learned }

class CategoryRule extends Equatable {
  const CategoryRule({
    required this.id,
    required this.userId,
    required this.matcher,
    required this.matcherType,
    required this.categoryId,
    required this.source,
  });

  final String id;
  final String userId;
  final String matcher;
  final CategoryRuleMatcherType matcherType;
  final String categoryId;
  final CategoryRuleSource source;

  factory CategoryRule.fromJson(Map<String, dynamic> json) {
    return CategoryRule(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      matcher: json['matcher'] as String,
      matcherType: _parseMatcherType(json['matcher_type'] as String),
      categoryId: json['category_id'] as String,
      source: CategoryRuleSource.values.byName(json['source'] as String),
    );
  }

  static CategoryRuleMatcherType _parseMatcherType(String value) {
    return switch (value) {
      'merchant' => CategoryRuleMatcherType.merchant,
      'monzo_category' => CategoryRuleMatcherType.monzoCategory,
      _ => CategoryRuleMatcherType.keyword,
    };
  }

  Map<String, dynamic> toInsertJson() => {
        'matcher': matcher,
        'matcher_type': _matcherTypeDbName,
        'category_id': categoryId,
        'source': source.name,
      };

  String get _matcherTypeDbName => switch (matcherType) {
        CategoryRuleMatcherType.merchant => 'merchant',
        CategoryRuleMatcherType.monzoCategory => 'monzo_category',
        CategoryRuleMatcherType.keyword => 'keyword',
      };

  @override
  List<Object?> get props => [id, matcher, matcherType, categoryId];
}
