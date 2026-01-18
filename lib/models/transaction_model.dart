import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/currency_data.dart';

class TransactionModel {
  final String id;
  final DateTime date;
  final DateTime? createdAt;
  final double amount;
  final String currency;
  final String categoryId;
  final String? merchant;
  final String? paymentMethod;
  final String? note;
  final String? receiptUrl;
  final bool splitPurchase;
  final bool recurringEnabled;
  final String? recurringInterval;
  final String? recurringParentId;
  final DateTime? recurringLastDate;

  const TransactionModel({
    required this.id,
    required this.date,
    this.createdAt,
    required this.amount,
    required this.currency,
    required this.categoryId,
    this.merchant,
    this.paymentMethod,
    this.note,
    this.receiptUrl,
    this.splitPurchase = false,
    this.recurringEnabled = false,
    this.recurringInterval,
    this.recurringParentId,
    this.recurringLastDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'currency': currency,
      'categoryId': categoryId,
      if (merchant != null && merchant!.trim().isNotEmpty) 'merchant': merchant,
      if (paymentMethod != null && paymentMethod!.trim().isNotEmpty)
        'paymentMethod': paymentMethod,
      if (note != null && note!.trim().isNotEmpty) 'note': note,
      if (receiptUrl != null && receiptUrl!.trim().isNotEmpty) 'receiptUrl': receiptUrl,
      if (splitPurchase) 'splitPurchase': true,
      if (recurringEnabled) 'recurringEnabled': true,
      if (recurringInterval != null) 'recurringInterval': recurringInterval,
      if (recurringParentId != null) 'recurringParentId': recurringParentId,
      if (recurringEnabled && recurringLastDate != null)
        'recurringLastDate': Timestamp.fromDate(recurringLastDate!),
    };
  }

  factory TransactionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final dateTs = data['date'];
    final createdAtTs = data['createdAt'];
    final recurringLastDateTs = data['recurringLastDate'];

    return TransactionModel(
      id: doc.id,
      date: dateTs is Timestamp ? dateTs.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: createdAtTs is Timestamp ? createdAtTs.toDate() : null,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: (data['currency'] as String?) ?? defaultCurrencyCode,
      categoryId: (data['categoryId'] as String?) ?? '',
      merchant: data['merchant'] as String?,
      paymentMethod: data['paymentMethod'] as String?,
      note: data['note'] as String?,
      receiptUrl: data['receiptUrl'] as String?,
      splitPurchase: (data['splitPurchase'] as bool?) ?? false,
      recurringEnabled: (data['recurringEnabled'] as bool?) ?? false,
      recurringInterval: data['recurringInterval'] as String?,
      recurringParentId: data['recurringParentId'] as String?,
      recurringLastDate:
          recurringLastDateTs is Timestamp ? recurringLastDateTs.toDate() : null,
    );
  }

  TransactionModel copyWith({
    String? id,
    DateTime? date,
    DateTime? createdAt,
    double? amount,
    String? currency,
    String? categoryId,
    String? merchant,
    String? paymentMethod,
    String? note,
    String? receiptUrl,
    bool? splitPurchase,
    bool? recurringEnabled,
    String? recurringInterval,
    String? recurringParentId,
    DateTime? recurringLastDate,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      merchant: merchant ?? this.merchant,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      splitPurchase: splitPurchase ?? this.splitPurchase,
      recurringEnabled: recurringEnabled ?? this.recurringEnabled,
      recurringInterval: recurringInterval ?? this.recurringInterval,
      recurringParentId: recurringParentId ?? this.recurringParentId,
      recurringLastDate: recurringLastDate ?? this.recurringLastDate,
    );
  }
}
