import 'package:equatable/equatable.dart';

enum RecurringCadence { weekly, monthly, quarterly, yearly }

class RecurringPayment extends Equatable {
  const RecurringPayment({
    required this.id,
    required this.userId,
    required this.name,
    required this.amountPence,
    required this.currency,
    required this.cadence,
    required this.nextDate,
    this.accountId,
    this.categoryId,
    required this.autoDetected,
    this.categoryName,
  });

  final String id;
  final String userId;
  final String name;
  final int amountPence;
  final String currency;
  final RecurringCadence cadence;
  final DateTime nextDate;
  final String? accountId;
  final String? categoryId;
  final bool autoDetected;
  final String? categoryName;

  factory RecurringPayment.fromJson(Map<String, dynamic> json) {
    return RecurringPayment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      amountPence: (json['amount_pence'] as num).toInt(),
      currency: json['currency'] as String? ?? 'GBP',
      cadence: RecurringCadence.values.byName(json['cadence'] as String),
      nextDate: DateTime.parse(json['next_date'] as String),
      accountId: json['account_id'] as String?,
      categoryId: json['category_id'] as String?,
      autoDetected: json['auto_detected'] as bool? ?? false,
      categoryName: json['categories'] is Map
          ? (json['categories'] as Map)['name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount_pence': amountPence,
        'currency': currency,
        'cadence': cadence.name,
        'next_date': nextDate.toIso8601String().split('T').first,
        'account_id': accountId,
        'category_id': categoryId,
        'auto_detected': autoDetected,
      };

  DateTime advanceNextDate() {
    switch (cadence) {
      case RecurringCadence.weekly:
        return nextDate.add(const Duration(days: 7));
      case RecurringCadence.monthly:
        return DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
      case RecurringCadence.quarterly:
        return DateTime(nextDate.year, nextDate.month + 3, nextDate.day);
      case RecurringCadence.yearly:
        return DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
    }
  }

  @override
  List<Object?> get props => [id, name, nextDate];
}
