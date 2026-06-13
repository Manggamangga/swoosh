import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/chart_theme.dart';
import 'package:swoosh/core/theme/spacing.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/providers/data_providers.dart';

class CategoryTrendChart extends StatelessWidget {
  const CategoryTrendChart({
    super.key,
    required this.points,
    required this.categoryColor,
  });

  final List<CategoryMonthPoint> points;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    if (points.every((p) => p.spentPence == 0)) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No spending in this category yet',
            style: AppTextStyles.bodyMuted(context),
          ),
        ),
      );
    }

    final maxSpent = points
        .map((p) => p.spentPence)
        .fold<int>(0, (max, v) => v > max ? v : max);
    final maxY = (maxSpent / 100) * 1.15;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY > 0 ? maxY : 1,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('MMM').format(points[index].month),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: AppRadius.md,
              getTooltipColor: (_) => AppColors.surfaceElevated,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  Money.format(points[groupIndex].spentPence),
                  const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                );
              },
            ),
          ),
          barGroups: points.asMap().entries.map((entry) {
            final isLatest = entry.key == points.length - 1;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.spentPence / 100,
                  color: isLatest
                      ? categoryColor
                      : categoryColor.withValues(alpha: 0.45),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        duration: ChartTheme.animationDuration,
        curve: ChartTheme.curve,
      ),
    );
  }
}
