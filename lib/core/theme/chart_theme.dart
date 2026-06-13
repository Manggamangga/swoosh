import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/spacing.dart';
import 'package:swoosh/core/utils/money.dart';

abstract final class ChartTheme {
  static const animationDuration = Duration(milliseconds: 600);
  static const curve = Curves.easeOutCubic;

  static LineTouchTooltipData lineTooltip() => LineTouchTooltipData(
        tooltipRoundedRadius: AppRadius.md,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        getTooltipColor: (_) => AppColors.surfaceElevated,
        getTooltipItems: (spots) => spots
            .map(
              (spot) => LineTooltipItem(
                Money.format((spot.y * 100).round()),
                const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            )
            .toList(),
      );

  static LineChartBarData primaryLine({
    required List<FlSpot> spots,
    Color color = AppColors.primary,
    double barWidth = 3,
    bool showDots = false,
    bool showArea = true,
  }) =>
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: barWidth,
        dotData: FlDotData(show: showDots),
        belowBarData: BarAreaData(
          show: showArea,
          color: color.withValues(alpha: 0.12),
        ),
      );

  static LineChartData balanceLineChart({
    required List<FlSpot> spots,
    Color lineColor = AppColors.primary,
  }) {
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      minY: minY - padding,
      maxY: maxY + padding,
      lineTouchData: LineTouchData(touchTooltipData: lineTooltip()),
      lineBarsData: [
        primaryLine(spots: spots, color: lineColor),
      ],
    );
  }

  static PieChartData donut({
    required List<PieChartSectionData> sections,
    double centerSpaceRadius = 42,
    double sectionSpace = 2,
  }) =>
      PieChartData(
        sectionsSpace: sectionSpace,
        centerSpaceRadius: centerSpaceRadius,
        sections: sections,
      );
}
