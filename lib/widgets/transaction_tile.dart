import 'package:flutter/material.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel tx;
  final CategoryModel? category;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.tx,
    required this.category,
    this.onTap,
  });

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = (tx.merchant ?? '').trim().isEmpty ? null : tx.merchant!.trim();
    final categoryLabel = category == null ? 'Unknown category' : category!.name;
    final icon = category?.icon ?? '🏷️';

    return ListTile(
      leading: CircleAvatar(child: Text(icon)),
      title: Text(title ?? categoryLabel),
      subtitle: Text('${_formatDate(tx.date)} • $categoryLabel'),
      trailing: Text(
        '₪ ${tx.amount.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: onTap,
    );
  }
}

