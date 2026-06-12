class CsvStatementParseResult {
  const CsvStatementParseResult({
    required this.rows,
    this.institution,
    this.closingBalancePence,
  });

  final List<Map<String, dynamic>> rows;
  final String? institution;
  final int? closingBalancePence;
}
