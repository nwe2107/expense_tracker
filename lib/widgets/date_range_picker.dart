import 'package:flutter/material.dart';

class MonthYearPicker extends StatelessWidget {
  final int year;
  final int month;
  final ValueChanged<DateTime> onChanged;

  const MonthYearPicker({
    super.key,
    required this.year,
    required this.month,
    required this.onChanged,
  });

  static const _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _monthLabel(int month) => _monthNames[(month - 1).clamp(0, 11)];

  Future<void> _pickMonthYear(BuildContext context) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        int selectedYear = year;
        int selectedMonth = month;

        return AlertDialog(
          title: const Text('Pick month'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedYear,
                    items: List.generate(
                      101,
                      (i) => DropdownMenuItem(
                        value: 2000 + i,
                        child: Text('${2000 + i}'),
                      ),
                    ),
                    onChanged: (v) => setState(() => selectedYear = v ?? selectedYear),
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedMonth,
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_monthLabel(i + 1)),
                      ),
                    ),
                    onChanged: (v) => setState(() => selectedMonth = v ?? selectedMonth),
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                DateTime(selectedYear, selectedMonth, 1),
              ),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (picked == null) return;
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => onChanged(DateTime(year, month - 1, 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pickMonthYear(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Month',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_monthLabel(month)} $year',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to change',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => onChanged(DateTime(year, month + 1, 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}
