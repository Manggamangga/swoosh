import 'package:equatable/equatable.dart';

enum AccountType { everyday, savings, investment }

enum DataSource { manual, csv, openbanking }

class Account extends Equatable {
  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.accountType,
    required this.balancePence,
    required this.currency,
    this.institution,
    required this.source,
    this.externalRef,
    this.balanceAnchorPence,
    this.balanceAnchorDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final AccountType accountType;
  final int balancePence;
  final String currency;
  final String? institution;
  final DataSource source;
  final String? externalRef;
  final int? balanceAnchorPence;
  final DateTime? balanceAnchorDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      accountType: AccountType.values.byName(json['account_type'] as String),
      balancePence: (json['balance_pence'] as num).toInt(),
      currency: json['currency'] as String? ?? 'GBP',
      institution: json['institution'] as String?,
      source: DataSource.values.byName(json['source'] as String),
      externalRef: json['external_ref'] as String?,
      balanceAnchorPence: (json['balance_anchor_pence'] as num?)?.toInt(),
      balanceAnchorDate: json['balance_anchor_date'] != null
          ? DateTime.parse(json['balance_anchor_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'account_type': accountType.name,
        'balance_pence': balancePence,
        'currency': currency,
        'institution': institution,
        'source': source.name,
        'external_ref': externalRef,
        'balance_anchor_pence': balanceAnchorPence,
        'balance_anchor_date': balanceAnchorDate?.toIso8601String().split('T').first,
      };

  Account copyWith({
    String? name,
    AccountType? accountType,
    int? balancePence,
    String? institution,
    int? balanceAnchorPence,
    DateTime? balanceAnchorDate,
  }) {
    return Account(
      id: id,
      userId: userId,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      balancePence: balancePence ?? this.balancePence,
      currency: currency,
      institution: institution ?? this.institution,
      source: source,
      externalRef: externalRef,
      balanceAnchorPence: balanceAnchorPence ?? this.balanceAnchorPence,
      balanceAnchorDate: balanceAnchorDate ?? this.balanceAnchorDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, balancePence, name];
}
