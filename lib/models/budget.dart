import 'package:equatable/equatable.dart';

class Budget extends Equatable {
  const Budget({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.periodMonth,
    required this.amountPence,
    this.categoryName,
    this.categoryColor,
    this.spentPence = 0,
  });

  final String id;
  final String userId;
  final String categoryId;
  final DateTime periodMonth;
  final int amountPence;
  final String? categoryName;
  final String? categoryColor;
  final int spentPence;

  double get progress => amountPence == 0 ? 0 : (spentPence / amountPence).clamp(0, 2);
  bool get isOverBudget => spentPence > amountPence;
  int get remainingPence =>
      (amountPence - spentPence).clamp(0, amountPence);

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String,
      periodMonth: DateTime.parse(json['period_month'] as String),
      amountPence: (json['amount_pence'] as num).toInt(),
      categoryName: json['categories'] is Map
          ? (json['categories'] as Map)['name'] as String?
          : null,
      categoryColor: json['categories'] is Map
          ? (json['categories'] as Map)['color'] as String?
          : null,
      spentPence: (json['spent_pence'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'period_month': periodMonth.toIso8601String().split('T').first,
        'amount_pence': amountPence,
      };

  Budget copyWith({int? spentPence}) => Budget(
        id: id,
        userId: userId,
        categoryId: categoryId,
        periodMonth: periodMonth,
        amountPence: amountPence,
        categoryName: categoryName,
        categoryColor: categoryColor,
        spentPence: spentPence ?? this.spentPence,
      );

  @override
  List<Object?> get props => [id, amountPence, spentPence];
}
