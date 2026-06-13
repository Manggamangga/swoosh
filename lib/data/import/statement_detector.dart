import 'dart:typed_data';

import 'package:swoosh/data/import/adapters/amex_csv_adapter.dart';
import 'package:swoosh/data/import/adapters/barclays_csv_adapter.dart';
import 'package:swoosh/data/import/adapters/barclays_pdf_adapter.dart';
import 'package:swoosh/data/import/adapters/generic_csv_adapter.dart';
import 'package:swoosh/data/import/adapters/wise_activity_csv_adapter.dart';
import 'package:swoosh/data/import/adapters/wise_csv_adapter.dart';
import 'package:swoosh/data/import/adapters/wise_pdf_adapter.dart';
import 'package:swoosh/data/import/csv_parse_utils.dart';
import 'package:swoosh/data/import/statement_adapter.dart';

class StatementDetector {
  StatementDetector({
    List<StatementAdapter>? adapters,
    AmexCsvAdapter? amexAdapter,
    BarclaysCsvAdapter? barclaysAdapter,
    BarclaysPdfAdapter? barclaysPdfAdapter,
    WiseCsvAdapter? wiseAdapter,
    WiseActivityCsvAdapter? wiseActivityAdapter,
    WisePdfAdapter? wisePdfAdapter,
    GenericCsvAdapter? genericAdapter,
    String Function(Uint8List bytes)? pdfTextExtractor,
  })  : _amexAdapter = amexAdapter ?? AmexCsvAdapter(),
        _barclaysAdapter = barclaysAdapter ?? BarclaysCsvAdapter(),
        _barclaysPdfAdapter = barclaysPdfAdapter ??
            BarclaysPdfAdapter(textExtractor: pdfTextExtractor),
        _wiseAdapter = wiseAdapter ?? WiseCsvAdapter(),
        _wiseActivityAdapter = wiseActivityAdapter ?? WiseActivityCsvAdapter(),
        _wisePdfAdapter = wisePdfAdapter ??
            WisePdfAdapter(textExtractor: pdfTextExtractor),
        _genericAdapter = genericAdapter ?? GenericCsvAdapter(),
        _adapters = adapters ??
            [
              wisePdfAdapter ??
                  WisePdfAdapter(textExtractor: pdfTextExtractor),
              barclaysPdfAdapter ??
                  BarclaysPdfAdapter(textExtractor: pdfTextExtractor),
              barclaysAdapter ?? BarclaysCsvAdapter(),
              wiseActivityAdapter ?? WiseActivityCsvAdapter(),
              wiseAdapter ?? WiseCsvAdapter(),
              amexAdapter ?? AmexCsvAdapter(),
              genericAdapter ?? GenericCsvAdapter(),
            ];

  final AmexCsvAdapter _amexAdapter;
  final BarclaysCsvAdapter _barclaysAdapter;
  final BarclaysPdfAdapter _barclaysPdfAdapter;
  final WiseCsvAdapter _wiseAdapter;
  final WiseActivityCsvAdapter _wiseActivityAdapter;
  final WisePdfAdapter _wisePdfAdapter;
  final GenericCsvAdapter _genericAdapter;
  final List<StatementAdapter> _adapters;

  StatementAdapter detect(Uint8List bytes, String filename) {
    if (BarclaysPdfAdapter.isPdfFile(filename, bytes)) {
      final text = _wisePdfAdapter.extractText(bytes);
      if (WisePdfAdapter.matchesContent(text)) {
        return _wisePdfAdapter;
      }
      if (BarclaysPdfAdapter.matchesContent(text)) {
        return _barclaysPdfAdapter;
      }
    }

    final rows = parseCsvRows(bytes);
    if (rows.isEmpty) return _genericAdapter;

    final dataStartIndex = findDataStartIndex(rows);
    if (dataStartIndex >= rows.length) return _genericAdapter;

    final header = normalizeHeader(rows[dataStartIndex]);
    if (BarclaysCsvAdapter.matchesHeader(header)) {
      return _barclaysAdapter;
    }

    if (WiseActivityCsvAdapter.matchesHeader(header)) {
      return _wiseActivityAdapter;
    }

    if (WiseCsvAdapter.matchesHeader(header)) {
      return _wiseAdapter;
    }

    if (AmexCsvAdapter.matchesHeader(header)) {
      return _amexAdapter;
    }

    return _genericAdapter;
  }

  List<StatementAdapter> get adapters => List.unmodifiable(_adapters);
}
