import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'edit_transaction_page.dart';
import '../services/vision_ocr_service.dart';

class ScanExpensePage extends StatefulWidget {
  final String uid;

  const ScanExpensePage({super.key, required this.uid});

  @override
  State<ScanExpensePage> createState() => _ScanExpensePageState();
}

class _ScanExpensePageState extends State<ScanExpensePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final VisionOcrService _ocrService = VisionOcrService();

  XFile? _imageFile;
  Uint8List? _imageBytes;
  String? _rawText;
  TransactionPrefill? _prefill;
  bool _processing = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2400,
        imageQuality: 90,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final parsed = await _runOcr(picked, bytes);

      if (!mounted) return;
      setState(() {
        _imageFile = picked;
        _imageBytes = bytes;
        _rawText = parsed.$1;
        _prefill = parsed.$2;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to scan: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<(String, TransactionPrefill?)> _runOcr(XFile file, Uint8List bytes) async {
    final rawText = (await _ocrService.detectReceiptText(bytes: bytes)).trim();
    if (rawText.isEmpty) return (rawText, null);
    return (rawText, _parseReceiptText(rawText, file, bytes));
  }

  TransactionPrefill _parseReceiptText(String text, XFile file, Uint8List bytes) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final merchant = _extractMerchant(lines);
    final amount = _extractAmount(lines);
    final date = _extractDate(lines);
    final paymentMethod = _extractPaymentMethod(lines);
    final categoryName = _extractCategoryHint(lines, merchant);

    return TransactionPrefill(
      note: merchant == null ? 'Receipt scan' : 'Receipt: $merchant',
      merchant: merchant,
      amount: amount,
      date: date,
      paymentMethod: paymentMethod,
      categoryName: categoryName,
      receiptFile: file,
      receiptBytes: bytes,
    );
  }

  String? _extractMerchant(List<String> lines) {
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (RegExp(r'\d').hasMatch(line) && line.length < 4) continue;
      if (lower.contains('total') ||
          lower.contains('amount') ||
          lower.contains('tax') ||
          lower.contains('cash') ||
          lower.contains('card')) {
        continue;
      }
      if (RegExp(r'[a-zA-Zא-ת]').hasMatch(line)) {
        return line;
      }
    }
    return lines.isEmpty ? null : lines.first;
  }

  double? _extractAmount(List<String> lines) {
    final keywordPatterns = [
      RegExp(r'(total|grand total|total due|amount due|balance due|sum)', caseSensitive: false),
      RegExp(r'(סה\"?כ|סך\s*הכל|סכום\s*לתשלום|לתשלום|סכום)', caseSensitive: false),
    ];

    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      final hasKeyword = keywordPatterns.any((p) => p.hasMatch(line));
      if (!hasKeyword) continue;

      final inline = _extractAmountsFromLine(line);
      if (inline.isNotEmpty) return inline.first;

      final lookahead = [i + 1, i + 2];
      for (final idx in lookahead) {
        if (idx >= lines.length) continue;
        final nextAmounts = _extractAmountsFromLine(lines[idx]);
        if (nextAmounts.isNotEmpty) return nextAmounts.first;
      }
    }

    final allCandidates = <double>[];
    for (final line in lines) {
      allCandidates.addAll(_extractAmountsFromLine(line));
    }
    if (allCandidates.isEmpty) return null;
    allCandidates.sort();
    return allCandidates.last;
  }

  List<double> _extractAmountsFromLine(String line) {
    final pattern = RegExp(r'([₪$€]?\s*[0-9]+(?:[.,][0-9]{2}))');
    final values = <double>[];
    for (final match in pattern.allMatches(line)) {
      final raw = match.group(1);
      if (raw == null) continue;
      final value = _parseAmountValue(raw);
      if (value == null) continue;
      if (!_isLikelyAmount(raw, value)) continue;
      values.add(value);
    }
    values.sort();
    return values;
  }

  bool _isLikelyAmount(String raw, double value) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length > 6) return false;
    if (value <= 0) return false;
    if (value >= 100000) return false;
    return true;
  }

  double? _parseAmountValue(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\d.,]'), '');
    if (cleaned.isEmpty) return null;
    final normalized = cleaned.contains(',') && cleaned.contains('.')
        ? cleaned.replaceAll(',', '')
        : cleaned.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String? _extractPaymentMethod(List<String> lines) {
    final joined = lines.join(' ').toLowerCase();
    if (joined.contains('apple pay')) return 'Apple Pay';
    if (joined.contains('bit')) return 'BIT Transfer';
    if (joined.contains('credit') || joined.contains('אשראי') || joined.contains('כרטיס')) {
      return 'credit';
    }
    if (joined.contains('debit') || joined.contains('דביט')) return 'debit';
    if (joined.contains('cash') || joined.contains('מזומן')) return 'cash';
    return null;
  }

  String? _extractCategoryHint(List<String> lines, String? merchant) {
    final joined = lines.join(' ').toLowerCase();
    final combined = merchant == null ? joined : '$joined ${merchant.toLowerCase()}';

    final restaurantHints = [
      'מסעדה',
      'מסעדת',
      'קפה',
      'בית קפה',
      'בורגר',
      'פיצה',
      'סושי',
      'שווארמה',
      'המבורגר',
    ];
    if (restaurantHints.any(combined.contains)) {
      return 'אוכל במסעדה';
    }

    final groceryHints = [
      'סופר',
      'מרכול',
      'מכולת',
      'מזון',
      'ירקות',
      'פירות',
      'עוגיות',
      'מעדניה',
      'מאפיה',
      'מאפים',
      'קונדיטוריה',
    ];
    if (groceryHints.any(combined.contains)) return 'מצרכי מזון';
    return null;
  }

  DateTime? _extractDate(List<String> lines) {
    final yearFirst = RegExp(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b');
    final dayFirst = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b');

    for (final line in lines) {
      final matchYearFirst = yearFirst.firstMatch(line);
      if (matchYearFirst != null) {
        return _buildDate(matchYearFirst.group(1), matchYearFirst.group(2), matchYearFirst.group(3));
      }
      final matchDayFirst = dayFirst.firstMatch(line);
      if (matchDayFirst != null) {
        return _buildDate(matchDayFirst.group(3), matchDayFirst.group(2), matchDayFirst.group(1));
      }
    }
    return null;
  }

  DateTime? _buildDate(String? yearRaw, String? monthRaw, String? dayRaw) {
    if (yearRaw == null || monthRaw == null || dayRaw == null) return null;
    var year = int.tryParse(yearRaw);
    if (year == null) return null;
    if (year < 100) year += 2000;
    final month = int.tryParse(monthRaw);
    final day = int.tryParse(dayRaw);
    if (month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  void _useScan() {
    final prefill = _prefill;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditTransactionPage(
          uid: widget.uid,
          prefill: prefill,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageFile != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Align the receipt inside the frame. We’ll scan and extract the total, date, and merchant.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: hasImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(_imageFile!.path),
                              fit: BoxFit.cover,
                            ),
                          )
                        : Center(
                            child: Text(
                              'Ready to scan',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            if (_processing)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: CircularProgressIndicator(),
              ),
            if (_prefill != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detected fields',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        _FieldRow(label: 'Merchant', value: _prefill?.merchant),
                        _FieldRow(
                          label: 'Amount',
                          value: _prefill?.amount?.toStringAsFixed(2),
                        ),
                        _FieldRow(
                          label: 'Date',
                          value: _prefill?.date?.toString().split(' ').first,
                        ),
                        if (_rawText != null)
                          TextButton.icon(
                            onPressed: () => _showRawText(_rawText!),
                            icon: const Icon(Icons.text_snippet_outlined),
                            label: const Text('View OCR text'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _processing ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Scan with camera'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _processing ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Upload from photos'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _prefill == null ? null : _useScan,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Use this scan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRawText(String text) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(text),
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String? value;

  const _FieldRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(value == null || value!.isEmpty ? '—' : value!),
          ),
        ],
      ),
    );
  }
}
