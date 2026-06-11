import 'package:equatable/equatable.dart';
import 'package:swoosh/models/account.dart';

class Transaction extends Equatable {
  const Transaction({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.transactionDate,
    required this.amountPence,
    required this.currency,
    required this.description,
    this.merchant,
    this.categoryId,
    required this.source,
    this.externalRef,
    required this.dedupeHash,
    this.transferPairId,
    required this.excludeFromAnalytics,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryColor,
    this.accountName,
  });

  final String id;
  final String userId;
  final String accountId;
  final DateTime transactionDate;
  final int amountPence;
  final String currency;
  final String description;
  final String? merchant;
  final String? categoryId;
  final DataSource source;
  final String? externalRef;
  final String dedupeHash;
  final String? transferPairId;
  final bool excludeFromAnalytics;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? categoryName;
  final String? categoryColor;
  final String? accountName;

  bool get isIncome => amountPence > 0;
  bool get isExpense => amountPence < 0;
  bool get isExcluded => excludeFromAnalytics;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      accountId: json['account_id'] as String,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      amountPence: (json['amount_pence'] as num).toInt(),
      currency: json['currency'] as String? ?? 'GBP',
      description: json['description'] as String? ?? '',
      merchant: json['merchant'] as String?,
      categoryId: json['category_id'] as String?,
      source: DataSource.values.byName(json['source'] as String),
      externalRef: json['external_ref'] as String?,
      dedupeHash: json['dedupe_hash'] as String,
      transferPairId: json['transfer_pair_id'] as String?,
      excludeFromAnalytics: json['exclude_from_analytics'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      categoryName: json['categories'] is Map
          ? (json['categories'] as Map)['name'] as String?
          : null,
      categoryColor: json['categories'] is Map
          ? (json['categories'] as Map)['color'] as String?
          : null,
      accountName: json['accounts'] is Map
          ? (json['accounts'] as Map)['name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'account_id': accountId,
        'transaction_date': transactionDate.toIso8601String().split('T').first,
        'amount_pence': amountPence,
        'currency': currency,
        'description': description,
        'merchant': merchant,
        'category_id': categoryId,
        'source': source.name,
        'external_ref': externalRef,
        'dedupe_hash': dedupeHash,
        'transfer_pair_id': transferPairId,
        'exclude_from_analytics': excludeFromAnalytics,
      };

  @override
  List<Object?> get props => [id, amountPence, transactionDate];
}
