import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:swoosh/core/services/balance_history_service.dart';
import 'package:swoosh/core/theme/chart_theme.dart';
import 'package:swoosh/core/theme/spacing.dart';

class BalanceChart extends StatelessWidget {
  const BalanceChart({
    super.key,
    required this.points,
  });

  final List<BalancePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No balance history yet',
            style: AppTextStyles.bodyMuted(context),
          ),
        ),
      );
    }

    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.balancePence / 100))
        .toList();

    return SizedBox(
      height: 180,
      child: LineChart(
        ChartTheme.balanceLineChart(spots: spots),
        duration: ChartTheme.animationDuration,
        curve: ChartTheme.curve,
      ),
    );
  }
}
