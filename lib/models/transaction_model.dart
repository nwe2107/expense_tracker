import 'package:cloud_firestore/cloud_firestore.dart';

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
  final bool splitPurchase;

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
    this.splitPurchase = false,
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
      if (splitPurchase) 'splitPurchase': true,
    };
  }

  factory TransactionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final dateTs = data['date'];
    final createdAtTs = data['createdAt'];

    return TransactionModel(
      id: doc.id,
      date: dateTs is Timestamp ? dateTs.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: createdAtTs is Timestamp ? createdAtTs.toDate() : null,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: (data['currency'] as String?) ?? 'ILS',
      categoryId: (data['categoryId'] as String?) ?? '',
      merchant: data['merchant'] as String?,
      paymentMethod: data['paymentMethod'] as String?,
      note: data['note'] as String?,
      splitPurchase: (data['splitPurchase'] as bool?) ?? false,
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
    bool? splitPurchase,
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
      splitPurchase: splitPurchase ?? this.splitPurchase,
    );
  }
}
