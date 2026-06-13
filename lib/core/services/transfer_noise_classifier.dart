class TransferClassification {
  const TransferClassification({
    required this.isTransfer,
    required this.isExcluded,
    this.reason,
  });

  final bool isTransfer;
  final bool isExcluded;
  final String? reason;
}

class TransferNoiseClassifier {
  static const excludedDetailTypes = {
    'CONVERSION',
    'INVESTMENT_TRADE_ORDER',
    'ACCRUAL_CHARGE',
    'MONEY_ADDED',
  };

  TransferClassification classifyTransaction({
    required String description,
    required int amountPence,
    Map<String, String>? metadata,
  }) {
    final normalizedDescription = description.trim();
    final detailsType =
        metadata?['transaction_details_type']?.trim().toUpperCase() ?? '';
    final transactionType =
        metadata?['transaction_type']?.trim().toUpperCase() ?? '';

    if (excludedDetailTypes.contains(detailsType)) {
      return TransferClassification(
        isTransfer: _isTransferLike(detailsType, transactionType),
        isExcluded: true,
        reason: 'transaction_details_type:$detailsType',
      );
    }

    if (_isOwnAccountTransfer(normalizedDescription)) {
      return TransferClassification(
        isTransfer: true,
        isExcluded: true,
        reason: 'own_account_transfer',
      );
    }

    return const TransferClassification(
      isTransfer: false,
      isExcluded: false,
    );
  }

  bool _isTransferLike(String detailsType, String transactionType) {
    if (detailsType == 'CONVERSION' ||
        detailsType == 'MONEY_ADDED' ||
        transactionType == 'TRANSFER') {
      return true;
    }
    return false;
  }

  bool _isOwnAccountTransfer(String description) {
    final upper = description.toUpperCase();

    if (upper.contains('SENT MONEY TO SEAN LOH')) {
      return true;
    }
    if (upper.contains('TOPPED UP ACCOUNT')) {
      return true;
    }
    if (upper.contains('RECEIVED MONEY FROM LOH S') &&
        upper.contains('SEAN WISE')) {
      return true;
    }

    return false;
  }
}
