import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/models/category_model.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/widgets/category_picker.dart';
import 'package:expense_tracker/widgets/transaction_tile.dart';

void main() {
  testWidgets('TransactionTile shows merchant and amount', (tester) async {
    final category = const CategoryModel(id: 'coffee', name: 'Coffee', icon: '☕️');
    final tx = TransactionModel(
      id: 'tx1',
      date: DateTime(2026, 1, 15),
      amount: 12.34,
      currency: 'ILS',
      categoryId: category.id,
      merchant: 'Coffee Shop',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionTile(tx: tx, category: category),
        ),
      ),
    );

    expect(find.text('Coffee Shop'), findsOneWidget);
    expect(find.textContaining('₪ 12.34'), findsOneWidget);
  });

  testWidgets('CategoryPicker renders selected category', (tester) async {
    final categories = const [
      CategoryModel(id: 'groceries', name: 'Groceries', icon: '🛒'),
      CategoryModel(id: 'eating_out', name: 'Eating Out', icon: '🍔'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryPicker(
            categories: categories,
            value: 'eating_out',
            enabled: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('🍔  Eating Out'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });
}
