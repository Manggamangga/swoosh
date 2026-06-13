import 'package:swoosh/data/import/generic_column_mapping.dart';
import 'package:swoosh/models/account.dart';

class ParsedTransaction {
  const ParsedTransaction({
    required this.date,
    required this.amountPence,
    required this.description,
    this.merchant,
    this.subcategory,
    this.excludeFromAnalytics = false,
    this.metadata,
    this.providerTxnId,
    this.currency = 'GBP',
  });

  final DateTime date;
  final int amountPence;
  final String description;
  final String? merchant;
  final String? subcategory;
  final bool excludeFromAnalytics;
  final Map<String, String>? metadata;
  final String? providerTxnId;
  final String currency;

  ParsedTransaction copyWith({
    DateTime? date,
    int? amountPence,
    String? description,
    String? merchant,
    String? subcategory,
    bool? excludeFromAnalytics,
    Map<String, String>? metadata,
    String? providerTxnId,
    String? currency,
  }) {
    return ParsedTransaction(
      date: date ?? this.date,
      amountPence: amountPence ?? this.amountPence,
      description: description ?? this.description,
      merchant: merchant ?? this.merchant,
      subcategory: subcategory ?? this.subcategory,
      excludeFromAnalytics: excludeFromAnalytics ?? this.excludeFromAnalytics,
      metadata: metadata ?? this.metadata,
      providerTxnId: providerTxnId ?? this.providerTxnId,
      currency: currency ?? this.currency,
    );
  }
}

class ParsedStatement {
  const ParsedStatement({
    required this.institution,
    this.accountIdentifier,
    required this.transactions,
    this.closingBalancePence,
    this.currency = 'GBP',
    this.accountType = AccountType.everyday,
    this.requiresImportReview = false,
    this.columnMapping,
  });

  final String institution;
  final String? accountIdentifier;
  final List<ParsedTransaction> transactions;
  final int? closingBalancePence;
  final String currency;
  final AccountType accountType;
  final bool requiresImportReview;
  final GenericColumnMapping? columnMapping;

  bool get isCreditAccount => accountType == AccountType.credit;

  String get suggestedAccountName {
    if (accountIdentifier != null) {
      final parts = accountIdentifier!.split(' ');
      final accountNumber = parts.isNotEmpty ? parts.last : accountIdentifier!;
      return '$institution · $accountNumber';
    }
    return institution;
  }
}