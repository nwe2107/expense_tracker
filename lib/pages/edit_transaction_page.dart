import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import '../services/receipt_storage_service.dart';
import '../widgets/category_picker.dart';

class EditTransactionPage extends StatefulWidget {
  final String uid;
  final TransactionModel? existing;

  const EditTransactionPage({super.key, required this.uid, this.existing});

  @override
  State<EditTransactionPage> createState() => _EditTransactionPageState();
}

class _EditTransactionPageState extends State<EditTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestore = FirestoreService();
  final ReceiptStorageService _receiptStorage = ReceiptStorageService();
  final ImagePicker _imagePicker = ImagePicker();

  static const List<String> _paymentMethods = [
    'cash',
    'credit',
    'debit',
    'BIT Transfer',
    'Apple Pay',
    'other',
  ];

  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;

  DateTime _date = DateTime.now();
  String _categoryId = '';
  String? _paymentMethod;
  bool _splitPurchase = false;
  bool _recurringEnabled = false;
  String? _recurringInterval;
  String? _receiptUrl;
  XFile? _receiptFile;
  Uint8List? _receiptBytes;

  bool _saving = false;

  bool get _isEditMode => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    _descriptionController = TextEditingController(text: existing?.note ?? '');
    _amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(2),
    );
    _merchantController = TextEditingController(text: existing?.merchant ?? '');

    _date = existing?.date ?? DateTime.now();
    _categoryId = existing?.categoryId ?? '';
    final existingPaymentMethod = existing?.paymentMethod;
    _paymentMethod = existingPaymentMethod != null && _paymentMethods.contains(existingPaymentMethod)
        ? existingPaymentMethod
        : null;
    _splitPurchase = existing?.splitPurchase ?? false;
    _recurringEnabled = existing?.recurringEnabled ?? false;
    if (existing?.recurringParentId != null) {
      _recurringEnabled = false;
    }
    _recurringInterval = _recurringEnabled ? existing?.recurringInterval : null;
    _receiptUrl = existing?.receiptUrl;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _receiptFile = picked;
      _receiptBytes = bytes;
    });
  }

  Future<void> _chooseReceiptSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickReceipt(source);
  }

  Future<void> _previewReceipt(String url) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              alignment: Alignment.centerLeft,
              child: const Text('Receipt'),
            ),
            Flexible(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Unable to load receipt image.'),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: DateTime(_date.year, _date.month, _date.day),
    );
    if (pickedDate == null) return;
    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (pickedTime == null) return;
    if (!mounted) return;

    setState(() {
      _date = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _formatDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _save() async {
    if (_saving) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_categoryId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a category.')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than 0.')),
      );
      return;
    }

    if (_recurringEnabled && _recurringInterval == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a recurring interval.')),
      );
      return;
    }

    setState(() => _saving = true);

    final transactionId =
        widget.existing?.id ?? _firestore.newTransactionId(widget.uid);
    var receiptUrl = _receiptUrl;

    if (_receiptFile != null) {
      final bytes = _receiptBytes ?? await _receiptFile!.readAsBytes();
      receiptUrl = await _receiptStorage.uploadReceipt(
        uid: widget.uid,
        transactionId: transactionId,
        bytes: bytes,
        fileName: _receiptFile!.name,
        mimeType: _receiptFile!.mimeType,
      );
    }

    final tx = TransactionModel(
      id: transactionId,
      date: _date,
      createdAt: widget.existing?.createdAt,
      amount: amount,
      currency: widget.existing?.currency ?? 'ILS',
      categoryId: _categoryId,
      note: _descriptionController.text.trim(),
      merchant: _merchantController.text.trim(),
      paymentMethod: _paymentMethod,
      receiptUrl: receiptUrl,
      splitPurchase: _splitPurchase,
      recurringEnabled: _recurringEnabled,
      recurringInterval: _recurringEnabled ? _recurringInterval : null,
      recurringParentId: widget.existing?.recurringParentId,
      recurringLastDate: widget.existing?.recurringLastDate,
    );

    try {
      if (_isEditMode) {
        await _firestore.updateTransaction(widget.uid, tx.id, tx);
      } else {
        await _firestore.addTransactionWithId(widget.uid, tx.id, tx);
      }
      if (_recurringEnabled) {
        await _firestore.ensureRecurringTransactions(widget.uid);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await _firestore.deleteTransaction(widget.uid, existing.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Expense' : 'Add Expense'),
        actions: [
          if (_isEditMode)
            IconButton(
              tooltip: 'Delete',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<CategoryModel>>(
          stream: _firestore.streamCategories(widget.uid),
          builder: (context, snapshot) {
            final categories = snapshot.data ?? const <CategoryModel>[];
            if (_categoryId.isEmpty && categories.isNotEmpty) {
              _categoryId = categories.first.id;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Description (required)',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Description is required.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date'),
                      subtitle: Text(_formatDateTime(_date)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: _saving ? null : _pickDateTime,
                    ),
                    const SizedBox(height: 12),
                    CategoryPicker(
                      uid: widget.uid,
                      categories: categories,
                      value: _categoryId.isEmpty ? null : _categoryId,
                      enabled: !_saving && categories.isNotEmpty,
                      onChanged: (value) {
                        setState(() => _categoryId = value ?? '');
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _merchantController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Merchant (required)',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Merchant is required.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Amount (required)',
                        prefixText: '₪ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Amount is required.';
                        final amount = double.tryParse(v);
                        if (amount == null || amount <= 0) return 'Enter a valid amount.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_paymentMethod ?? ''),
                      initialValue: _paymentMethod,
                      items: _paymentMethods
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(m),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() => _paymentMethod = value);
                            },
                      decoration: const InputDecoration(
                        labelText: 'Payment method (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Receipt (optional)'),
                      subtitle: Text(
                        _receiptFile != null
                            ? 'Receipt ready to upload.'
                            : (_receiptUrl == null || _receiptUrl!.isEmpty)
                                ? 'Add a receipt photo to keep with this expense.'
                                : 'Receipt attached.',
                      ),
                      trailing: OutlinedButton.icon(
                        onPressed: _saving ? null : _chooseReceiptSource,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(_receiptFile == null ? 'Add' : 'Replace'),
                      ),
                    ),
                    if (_receiptBytes != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _receiptBytes!,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _saving
                            ? null
                            : () {
                                setState(() {
                                  _receiptFile = null;
                                  _receiptBytes = null;
                                });
                              },
                        icon: const Icon(Icons.close),
                        label: const Text('Clear selection'),
                      ),
                    ] else if (_receiptUrl != null && _receiptUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _receiptUrl!,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Unable to load receipt preview.'),
                            );
                          },
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _saving ? null : () => _previewReceipt(_receiptUrl!),
                        icon: const Icon(Icons.open_in_full),
                        label: const Text('View'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Recurring expense? (optional)'),
                      subtitle: const Text('Automatically add future expenses.'),
                      value: _recurringEnabled,
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() {
                                _recurringEnabled = value;
                                if (_recurringEnabled) {
                                  _recurringInterval ??= 'monthly';
                                } else {
                                  _recurringInterval = null;
                                }
                              });
                            },
                    ),
                    if (_recurringEnabled) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_recurringInterval ?? ''),
                        initialValue: _recurringInterval,
                        items: const [
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                          DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                setState(() => _recurringInterval = value);
                              },
                        decoration: const InputDecoration(
                          labelText: 'Recurring interval',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Split purchase? (optional)'),
                      value: _splitPurchase,
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() => _splitPurchase = value);
                            },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving…' : 'Save'),
                      ),
                    ),
                    if (categories.isEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'No categories yet. Add some in Categories first.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
