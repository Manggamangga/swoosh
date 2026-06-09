import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swoosh/core/theme/app_colors.dart';

enum ChartPeriod { oneWeek, oneMonth, threeMonths, sixMonths, ytd, oneYear, all }

extension ChartPeriodLabel on ChartPeriod {
  String get label {
    switch (this) {
      case ChartPeriod.oneWeek:
        return '1W';
      case ChartPeriod.oneMonth:
        return '1M';
      case ChartPeriod.threeMonths:
        return '3M';
      case ChartPeriod.sixMonths:
        return '6M';
      case ChartPeriod.ytd:
        return 'YTD';
      case ChartPeriod.oneYear:
        return '1Y';
      case ChartPeriod.all:
        return 'ALL';
    }
  }

  DateTime startFrom(DateTime now) {
    switch (this) {
      case ChartPeriod.oneWeek:
        return now.subtract(const Duration(days: 7));
      case ChartPeriod.oneMonth:
        return DateTime(now.year, now.month - 1, now.day);
      case ChartPeriod.threeMonths:
        return DateTime(now.year, now.month - 3, now.day);
      case ChartPeriod.sixMonths:
        return DateTime(now.year, now.month - 6, now.day);
      case ChartPeriod.ytd:
        return DateTime(now.year, 1, 1);
      case ChartPeriod.oneYear:
        return DateTime(now.year - 1, now.month, now.day);
      case ChartPeriod.all:
        return DateTime(now.year - 5);
    }
  }
}

class PeriodPills extends StatelessWidget {
  const PeriodPills({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ChartPeriod selected;
  final ValueChanged<ChartPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ChartPeriod.values.map((period) {
          final isSelected = period == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(period);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  period.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
