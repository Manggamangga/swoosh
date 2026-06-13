class GenericColumnMapping {
  const GenericColumnMapping({
    this.dateColumn,
    this.descriptionColumn,
    this.amountColumn,
    this.debitColumn,
    this.creditColumn,
    this.balanceColumn,
  });

  final String? dateColumn;
  final String? descriptionColumn;
  final String? amountColumn;
  final String? debitColumn;
  final String? creditColumn;
  final String? balanceColumn;

  bool get hasAmountColumn =>
      amountColumn != null || debitColumn != null || creditColumn != null;
}
