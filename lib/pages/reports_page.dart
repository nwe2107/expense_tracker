import 'package:flutter/material.dart';

import '../charts/monthly_bar.dart';
import '../charts/spending_pie.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import '../widgets/date_range_picker.dart';

class ReportsPage extends StatefulWidget {
  final String uid;

  const ReportsPage({super.key, required this.uid});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final FirestoreService _firestore = FirestoreService();

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  List<Color> _palette(ThemeData theme) {
    return [
      theme.colorScheme.primary,
      theme.colorScheme.tertiary,
      theme.colorScheme.secondary,
      Colors.orange,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
    ];
  }

  static const _monthShort = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _monthLabel(int month) => _monthShort[(month - 1).clamp(0, 11)];

  DateTime _startOfMonth(DateTime dt) => DateTime(dt.year, dt.month, 1);

  DateTime _endOfMonth(DateTime dt) =>
      DateTime(dt.year, dt.month + 1, 1).subtract(const Duration(microseconds: 1));

  DateTime _startOfYear(int year) => DateTime(year, 1, 1);

  DateTime _endOfYear(int year) =>
      DateTime(year + 1, 1, 1).subtract(const Duration(microseconds: 1));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _palette(theme);

    final monthStart = _startOfMonth(_selectedMonth);
    final monthEnd = _endOfMonth(_selectedMonth);

    final selectedYear = _selectedMonth.year;
    final yearStart = _startOfYear(selectedYear);
    final yearEnd = _endOfYear(selectedYear);
    final months = List.generate(12, (i) => DateTime(selectedYear, i + 1, 1));

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: StreamBuilder<List<CategoryModel>>(
          stream: _firestore.streamCategories(widget.uid),
          builder: (context, catSnap) {
            final categories = catSnap.data ?? const <CategoryModel>[];
            final byId = <String, CategoryModel>{for (final c in categories) c.id: c};

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MonthYearPicker(
                  year: _selectedMonth.year,
                  month: _selectedMonth.month,
                  onChanged: (value) {
                    setState(() => _selectedMonth = DateTime(value.year, value.month, 1));
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Spending by category (${_monthLabel(_selectedMonth.month)} $selectedYear)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<TransactionModel>>(
                  stream: _firestore.streamTransactions(
                    widget.uid,
                    start: monthStart,
                    end: monthEnd,
                  ),
                  builder: (context, txSnap) {
                    if (txSnap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final txs = txSnap.data ?? const <TransactionModel>[];
                    final totals = <String, double>{};
                    for (final tx in txs) {
                      totals[tx.categoryId] = (totals[tx.categoryId] ?? 0) + tx.amount;
                    }

                    final entries = totals.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));

                    if (entries.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('No data for this range.')),
                      );
                    }

                    final sections = <SpendingPieSection>[];
                    for (var i = 0; i < entries.length; i++) {
                      final entry = entries[i];
                      final cat = byId[entry.key];
                      final label = cat == null ? 'Unknown' : '${cat.icon ?? '🏷️'}  ${cat.name}';
                      final color = cat?.color != null
                          ? Color(cat!.color!)
                          : palette[i % palette.length];
                      sections.add(SpendingPieSection(label: label, value: entry.value, color: color));
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SpendingPie(sections: sections),
                        const SizedBox(height: 8),
                        ...sections.map((s) {
                          return ListTile(
                            dense: true,
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: s.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(s.label),
                            trailing: Text('₪ ${s.value.toStringAsFixed(2)}'),
                          );
                        }),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Yearly spendings by month ($selectedYear)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<TransactionModel>>(
                  stream: _firestore.streamTransactions(
                    widget.uid,
                    start: yearStart,
                    end: yearEnd,
                  ),
                  builder: (context, txSnap) {
                    if (txSnap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final txs = txSnap.data ?? const <TransactionModel>[];
                    final byMonth = <int, double>{};
                    for (final tx in txs) {
                      if (tx.date.year != selectedYear) continue;
                      byMonth[tx.date.month] = (byMonth[tx.date.month] ?? 0) + tx.amount;
                    }

                    final monthLabels = months.map((m) => _monthLabel(m.month)).toList();
                    final monthValues = months.map((m) => byMonth[m.month] ?? 0).toList();

                    final monthEntries = <MapEntry<int, double>>[
                      for (var m = 1; m <= 12; m++) MapEntry(m, byMonth[m] ?? 0),
                    ]..removeWhere((e) => e.value <= 0);

                    if (monthEntries.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('No data for this year.')),
                      );
                    }

                    final monthPieSections = <SpendingPieSection>[];
                    for (var i = 0; i < monthEntries.length; i++) {
                      final entry = monthEntries[i];
                      monthPieSections.add(
                        SpendingPieSection(
                          label: _monthLabel(entry.key),
                          value: entry.value,
                          color: palette[i % palette.length],
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SpendingPie(sections: monthPieSections),
                        const SizedBox(height: 8),
                        ...monthPieSections.map((s) {
                          return ListTile(
                            dense: true,
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: s.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(s.label),
                            trailing: Text('₪ ${s.value.toStringAsFixed(2)}'),
                          );
                        }),
                        const SizedBox(height: 16),
                        Text('Monthly totals ($selectedYear)', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        MonthlyBar(labels: monthLabels, values: monthValues),
                        const SizedBox(height: 8),
                        Text(
                          'Total: ₪ ${monthValues.fold<double>(0, (p, v) => p + v).toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
