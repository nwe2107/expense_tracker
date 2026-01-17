import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MonthlyBar extends StatelessWidget {
  final List<String> labels;
  final List<double> values;

  const MonthlyBar({
    super.key,
    required this.labels,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty || values.isEmpty || labels.length != values.length) {
      return const SizedBox.shrink();
    }

    final maxY = values.fold<double>(
      0,
      (prev, v) => v > prev ? v : prev,
    );

    return AspectRatio(
      aspectRatio: 1.8,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY == 0 ? 1 : maxY * 1.2,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = labels[group.x.toInt()];
                return BarTooltipItem(
                  '$label\n₪ ${rod.toY.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    value.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      labels[idx],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(values.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 14,
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

