import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';

class ExportService {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  String formatRangeLabel(DateTime start, DateTime end) {
    return '${_dateFormat.format(start)} - ${_dateFormat.format(end)}';
  }

  String buildFileName({
    required DateTime start,
    required DateTime end,
    required String extension,
  }) {
    final startLabel = _dateFormat.format(start);
    final endLabel = _dateFormat.format(end);
    return 'expenses_${startLabel}_to_$endLabel.$extension';
  }

  Future<Uint8List> buildCsv({
    required List<TransactionModel> transactions,
    required Map<String, CategoryModel> categoriesById,
    required DateTime start,
    required DateTime end,
  }) async {
    return Isolate.run<Uint8List>(() {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

      final rows = <List<dynamic>>[];
      final totalsByCurrency = _totalsByCurrency(transactions);
      final totalsByCategory = _totalsByCategory(transactions, categoriesById);

      rows.add(['Expense report']);
      rows.add(['Period', '${dateFormat.format(start)} - ${dateFormat.format(end)}']);
      rows.add(['Generated', dateTimeFormat.format(DateTime.now())]);
      rows.add(['Transaction count', transactions.length]);
      for (final entry in totalsByCurrency.entries) {
        rows.add(['Total', entry.key, _formatAmount(entry.value)]);
      }
      rows.add([]);
      if (totalsByCategory.isNotEmpty) {
        rows.add(['Totals by category']);
        rows.add(['Category', 'Total']);
        for (final entry in totalsByCategory.entries) {
          rows.add([entry.key, _formatAmount(entry.value)]);
        }
        rows.add([]);
      }

      rows.add([
        'Date',
        'Category',
        'Merchant',
        'Payment method',
        'Note',
        'Amount',
        'Currency',
        'Receipt URL',
      ]);

      final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
      for (final tx in sorted) {
        rows.add([
          dateFormat.format(tx.date),
          _categoryName(tx, categoriesById),
          tx.merchant ?? '',
          tx.paymentMethod ?? '',
          tx.note ?? '',
          _formatAmount(tx.amount),
          tx.currency,
          tx.receiptUrl ?? '',
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      return Uint8List.fromList(utf8.encode(csv));
    });
  }

  Future<Uint8List> buildPdf({
    required List<TransactionModel> transactions,
    required Map<String, CategoryModel> categoriesById,
    required DateTime start,
    required DateTime end,
  }) async {
    final fontRegular = await PdfGoogleFonts.notoSansHebrewRegular();
    final fontBold = await PdfGoogleFonts.notoSansHebrewBold();
    
    return Isolate.run<Uint8List>(() {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
      final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

      final totalsByCurrency = _totalsByCurrency(transactions);
      final totalsByCategory = _totalsByCategory(transactions, categoriesById);
      final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          build: (context) => [
            pw.Text(
              'Expense report',
              style: pw.TextStyle(font: fontBold, fontSize: 20),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Period: ${dateFormat.format(start)} - ${dateFormat.format(end)}'),
            pw.Text('Generated: ${dateTimeFormat.format(DateTime.now())}'),
            pw.Text('Transaction count: ${transactions.length}'),
            pw.SizedBox(height: 10),
            if (totalsByCurrency.isNotEmpty) ...[
              pw.Text(
                'Totals by currency',
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                headers: const ['Currency', 'Total'],
                data: totalsByCurrency.entries
                    .map((e) => [e.key, _formatAmount(e.value)])
                    .toList(),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              ),
              pw.SizedBox(height: 8),
            ],
            if (totalsByCategory.isNotEmpty) ...[
              pw.Text(
                'Totals by category',
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
              pw.SizedBox(height: 4),
              _categoryTotalsTable(totalsByCategory, fontBold),
              pw.SizedBox(height: 12),
            ],
            pw.Text(
              'Transactions',
              style: pw.TextStyle(font: fontBold, fontSize: 12),
            ),
            pw.SizedBox(height: 4),
            if (sorted.isEmpty)
              pw.Text('No transactions in this period.')
            else
              _transactionsTable(sorted, categoriesById, fontBold, dateFormat),
          ],
        ),
      );

      return doc.save();
    });
  }

  static Map<String, double> _totalsByCurrency(List<TransactionModel> transactions) {
    final totals = <String, double>{};
    for (final tx in transactions) {
      totals[tx.currency] = (totals[tx.currency] ?? 0) + tx.amount;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return {for (final entry in entries) entry.key: entry.value};
  }

  static Map<String, double> _totalsByCategory(
    List<TransactionModel> transactions,
    Map<String, CategoryModel> categoriesById,
  ) {
    final totals = <String, double>{};
    for (final tx in transactions) {
      final name = _categoryName(tx, categoriesById);
      totals[name] = (totals[name] ?? 0) + tx.amount;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final entry in entries) entry.key: entry.value};
  }

  static String _categoryName(TransactionModel tx, Map<String, CategoryModel> categoriesById) {
    final cat = categoriesById[tx.categoryId];
    return cat?.name ?? 'Uncategorized';
  }

  static String _formatAmount(double amount) => amount.toStringAsFixed(2);

  static bool _hasHebrew(String value) => RegExp(r'[\u0590-\u05FF]').hasMatch(value);

  static pw.Widget _cellText(
    String value, {
    pw.TextStyle? style,
    bool rtl = false,
  }) {
    return pw.Text(
      value,
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      style: style,
      textAlign: rtl ? pw.TextAlign.right : pw.TextAlign.left,
    );
  }

  static pw.Widget _paddedCell(pw.Widget child) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: child,
    );
  }

  static pw.Widget _categoryTotalsTable(
    Map<String, double> totalsByCategory,
    pw.Font fontBold,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _paddedCell(
              _cellText(
                'Category',
                style: pw.TextStyle(font: fontBold, fontSize: 10),
              ),
            ),
            _paddedCell(
              _cellText(
                'Total',
                style: pw.TextStyle(font: fontBold, fontSize: 10),
              ),
            ),
          ],
        ),
        ...totalsByCategory.entries.map((entry) {
          final isRtl = _hasHebrew(entry.key);
          return pw.TableRow(
            children: [
              _paddedCell(
                _cellText(
                  entry.key,
                  style: const pw.TextStyle(fontSize: 9),
                  rtl: isRtl,
                ),
              ),
              _paddedCell(
                _cellText(
                  _formatAmount(entry.value),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _transactionsTable(
    List<TransactionModel> transactions,
    Map<String, CategoryModel> categoriesById,
    pw.Font fontBold,
    DateFormat dateFormat,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.1),
        1: pw.FlexColumnWidth(1.4),
        2: pw.FlexColumnWidth(1.4),
        3: pw.FlexColumnWidth(1.3),
        4: pw.FlexColumnWidth(1.8),
        5: pw.FlexColumnWidth(1),
        6: pw.FlexColumnWidth(0.9),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _paddedCell(
              _cellText(
                'Date',
                style: pw.TextStyle(font: fontBold, fontSize: 9),
              ),
            ),
            _paddedCell(
              _cellText(
                'Category',
                style: pw.TextStyle(font: fontBold, fontSize: 9),
              ),
            ),
            _paddedCell(
              _cellText(
                'Merchant',
                style: pw.TextStyle(font: fontBold, fontSize: 9),
              ),
            ),
            _paddedCell(
              _cellText(
                'Payment method',
                style: pw.TextStyle(font: fontBold, fontSize: 9),
              ),
            ),
            _paddedCell(
              _cellText(
                'Note',
                style: pw.TextStyle(font: fontBold, fontSize: 9),
              ),
            ),
            _paddedCell(
              _cellText(
                'Amount',
                style: pw.TextStyle(font: fontBold, fontSize: 9),
              ),
            ),
            _paddedCell(
              _cellText(
                'Currency',
                style: pw.TextStyle(font: fontBold, fontSize: 9),
              ),
            ),
          ],
        ),
        ...transactions.map((tx) {
          final category = _categoryName(tx, categoriesById);
          final isRtl = _hasHebrew(category);
          return pw.TableRow(
            children: [
              _paddedCell(
                _cellText(
                  dateFormat.format(tx.date),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              _paddedCell(
                _cellText(
                  category,
                  style: const pw.TextStyle(fontSize: 8),
                  rtl: isRtl,
                ),
              ),
              _paddedCell(
                _cellText(
                  tx.merchant ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              _paddedCell(
                _cellText(
                  tx.paymentMethod ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              _paddedCell(
                _cellText(
                  tx.note ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              _paddedCell(
                _cellText(
                  _formatAmount(tx.amount),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              _paddedCell(
                _cellText(
                  tx.currency,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}
