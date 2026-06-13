import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:swoosh/core/theme/chart_theme.dart';
import 'package:swoosh/providers/data_providers.dart';

class SpendingDonutChart extends StatelessWidget {
  const SpendingDonutChart({
    super.key,
    required this.categories,
    required this.totalSpentPence,
  });

  final List<CategorySpendingRow> categories;
  final int totalSpentPence;

  Color _parseColor(String hex) {
    final value = hex.replaceFirst('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty || totalSpentPence == 0) {
      return const SizedBox.shrink();
    }

    final sections = categories
        .where((row) => row.spentPence > 0)
        .map(
          (row) => PieChartSectionData(
            value: row.spentPence.toDouble(),
            color: _parseColor(row.categoryColor),
            radius: 28,
            title: '',
          ),
        )
        .toList();

    if (sections.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 160,
      child: PieChart(
        ChartTheme.donut(sections: sections),
        duration: ChartTheme.animationDuration,
        curve: ChartTheme.curve,
      ),
    );
  }
}
