import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SpendingPieSection {
  final String label;
  final double value;
  final Color color;

  const SpendingPieSection({
    required this.label,
    required this.value,
    required this.color,
  });
}

class SpendingPie extends StatelessWidget {
  final List<SpendingPieSection> sections;

  const SpendingPie({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = sections.fold<double>(0, (prev, s) => prev + s.value);

    return AspectRatio(
      aspectRatio: 1.35,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 38,
          sections: sections.map((s) {
            final pct = total == 0 ? 0 : (s.value / total) * 100;
            final title = pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '';
            return PieChartSectionData(
              value: s.value,
              color: s.color,
              radius: 56,
              title: title,
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

