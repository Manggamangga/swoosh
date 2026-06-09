import 'package:equatable/equatable.dart';

class Goal extends Equatable {
  const Goal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmountPence,
    required this.currentAmountPence,
    required this.currency,
    this.targetDate,
    this.accountId,
  });

  final String id;
  final String userId;
  final String name;
  final int targetAmountPence;
  final int currentAmountPence;
  final String currency;
  final DateTime? targetDate;
  final String? accountId;

  double get progress =>
      targetAmountPence == 0 ? 0 : (currentAmountPence / targetAmountPence).clamp(0, 1);

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      targetAmountPence: (json['target_amount_pence'] as num).toInt(),
      currentAmountPence: (json['current_amount_pence'] as num).toInt(),
      currency: json['currency'] as String? ?? 'GBP',
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'] as String)
          : null,
      accountId: json['account_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'target_amount_pence': targetAmountPence,
        'current_amount_pence': currentAmountPence,
        'currency': currency,
        'target_date': targetDate?.toIso8601String().split('T').first,
        'account_id': accountId,
      };

  @override
  List<Object?> get props => [id, currentAmountPence, targetAmountPence];
}
