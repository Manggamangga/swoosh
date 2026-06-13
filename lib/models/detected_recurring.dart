import 'package:equatable/equatable.dart';
import 'package:swoosh/models/recurring_payment.dart';

class DetectedRecurring extends Equatable {
  const DetectedRecurring({
    required this.detectionKey,
    required this.name,
    required this.typicalAmountPence,
    required this.cadence,
    required this.monthlyTotalPence,
    required this.lastSeenDate,
    required this.occurrenceCount,
    this.accountId,
    this.categoryId,
    this.currency = 'GBP',
  });

  final String detectionKey;
  final String name;
  final int typicalAmountPence;
  final RecurringCadence cadence;
  final int monthlyTotalPence;
  final DateTime lastSeenDate;
  final int occurrenceCount;
  final String? accountId;
  final String? categoryId;
  final String currency;

  @override
  List<Object?> get props => [detectionKey];
}
