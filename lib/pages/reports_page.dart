import 'package:flutter/material.dart';

import '../charts/monthly_bar.dart';
import '../charts/spending_pie.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/export_service.dart';
import '../services/firestore_service.dart';
import '../widgets/date_range_picker.dart';
import 'package:share_plus/share_plus.dart';

enum ExportPeriod { month, year, custom }

enum ExportFormat { csv, pdf }

class ReportsPage extends StatefulWidget {
  final String uid;
  final bool showAppBar;
  final bool useScaffold;

  const ReportsPage({
    super.key,
    required this.uid,
    this.showAppBar = true,
    this.useScaffold = true,
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final FirestoreService _firestore = FirestoreService();
  final ExportService _exportService = ExportService();

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

  DateTime _endOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999, 999);

  String _periodLabel(ExportPeriod period, DateTimeRange? customRange) {
    switch (period) {
      case ExportPeriod.month:
        return '${_monthLabel(_selectedMonth.month)} ${_selectedMonth.year}';
      case ExportPeriod.year:
        return '${_selectedMonth.year}';
      case ExportPeriod.custom:
        final range = customRange;
        if (range == null) return 'Custom period';
        return _exportService.formatRangeLabel(
          range.start,
          _endOfDay(range.end),
        );
    }
  }

  String _formatLabel(ExportFormat format) =>
      format == ExportFormat.csv ? 'CSV' : 'PDF';

  Future<void> _showExportSheet(Map<String, CategoryModel> categoriesById) async {
    ExportPeriod period = ExportPeriod.month;
    ExportFormat format = ExportFormat.csv;
    DateTimeRange? customRange;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Export data', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text('Period', style: Theme.of(context).textTheme.labelLarge),
                  RadioListTile<ExportPeriod>(
                    value: ExportPeriod.month,
                    groupValue: period,
                    onChanged: (value) => setState(() => period = value!),
                    title: const Text('Current month'),
                  ),
                  RadioListTile<ExportPeriod>(
                    value: ExportPeriod.year,
                    groupValue: period,
                    onChanged: (value) => setState(() => period = value!),
                    title: const Text('Current year'),
                  ),
                  RadioListTile<ExportPeriod>(
                    value: ExportPeriod.custom,
                    groupValue: period,
                    onChanged: (value) => setState(() => period = value!),
                    title: const Text('Custom period'),
                    subtitle: customRange == null
                        ? const Text('Select start and end dates')
                        : Text(
                            _exportService.formatRangeLabel(
                              customRange!.start,
                              _endOfDay(customRange!.end),
                            ),
                          ),
                    secondary: IconButton(
                      tooltip: 'Pick date range',
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          initialDateRange: customRange,
                        );
                        if (picked == null) return;
                        setState(() {
                          customRange = picked;
                          period = ExportPeriod.custom;
                        });
                      },
                      icon: const Icon(Icons.date_range),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Format', style: Theme.of(context).textTheme.labelLarge),
                  RadioListTile<ExportFormat>(
                    value: ExportFormat.csv,
                    groupValue: format,
                    onChanged: (value) => setState(() => format = value!),
                    title: const Text('CSV'),
                  ),
                  RadioListTile<ExportFormat>(
                    value: ExportFormat.pdf,
                    groupValue: format,
                    onChanged: (value) => setState(() => format = value!),
                    title: const Text('PDF'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      if (period == ExportPeriod.custom && customRange == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pick a custom period first.')),
                        );
                        return;
                      }

                      final label = _periodLabel(period, customRange);
                      Navigator.of(context).pop();
                      await _exportData(
                        categoriesById,
                        period,
                        format,
                        customRange,
                        label,
                      );
                    },
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportData(
    Map<String, CategoryModel> categoriesById,
    ExportPeriod period,
    ExportFormat format,
    DateTimeRange? customRange,
    String periodLabel,
  ) async {
    DateTime start;
    DateTime end;

    switch (period) {
      case ExportPeriod.month:
        start = _startOfMonth(_selectedMonth);
        end = _endOfMonth(_selectedMonth);
        break;
      case ExportPeriod.year:
        start = _startOfYear(_selectedMonth.year);
        end = _endOfYear(_selectedMonth.year);
        break;
      case ExportPeriod.custom:
        final range = customRange!;
        start = range.start;
        end = _endOfDay(range.end);
        break;
    }

    try {
      final transactions = await _firestore.fetchTransactions(
        widget.uid,
        start: start,
        end: end,
      );

      if (!mounted) return;

      if (transactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No transactions for $periodLabel.')),
        );
        return;
      }

      final extension = format == ExportFormat.csv ? 'csv' : 'pdf';
      final fileName = _exportService.buildFileName(
        start: start,
        end: end,
        extension: extension,
      );

      final bytes = format == ExportFormat.csv
          ? await _exportService.buildCsv(
              transactions: transactions,
              categoriesById: categoriesById,
              start: start,
              end: end,
            )
          : await _exportService.buildPdf(
              transactions: transactions,
              categoriesById: categoriesById,
              start: start,
              end: end,
            );

      if (!mounted) return;

      final subject = 'Expense report - $periodLabel';
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: format == ExportFormat.csv ? 'text/csv' : 'application/pdf',
          ),
        ],
        subject: subject,
        text: 'Expense report for $periodLabel (${_formatLabel(format)}).',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

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

    final body = SafeArea(
      child: StreamBuilder<List<TransactionModel>>(
        stream: _firestore.streamTransactions(widget.uid, limit: 1),
        builder: (context, hasTxSnap) {
          if (hasTxSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final hasAnyTransactions = (hasTxSnap.data ?? const <TransactionModel>[]).isNotEmpty;
          if (!hasAnyTransactions) {
            // Empty state for new accounts with no reports yet.
            return Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pie_chart_outline,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No reports yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add expenses to see charts and exports.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return StreamBuilder<List<CategoryModel>>(
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
                  Text('Export data', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.file_download),
                      title: const Text('Export transactions'),
                      subtitle: const Text('CSV or PDF for month, year, or custom range'),
                      trailing: FilledButton.tonal(
                        onPressed: () => _showExportSheet(byId),
                        child: const Text('Export'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                        final label =
                            cat == null ? 'Unknown' : '${cat.icon ?? '🏷️'}  ${cat.name}';
                        final color = cat?.color != null
                            ? Color(cat!.color!)
                            : palette[i % palette.length];
                        sections.add(
                          SpendingPieSection(label: label, value: entry.value, color: color),
                        );
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
          );
        },
      ),
    );

    if (!widget.useScaffold) {
      // Embed the report content inside another Scaffold (e.g., tab shell).
      return body;
    }

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('Reports')) : null,
      body: body,
    );
  }
}
