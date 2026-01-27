import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/date_range_picker.dart';
import '../../widgets/transaction_tile.dart';
import '../edit_transaction_page.dart';

class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  DateTime _rangeStart(DateTime month) => DateTime(month.year, month.month, 1);

  DateTime _rangeEnd(DateTime month) =>
      DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999, 999);

  Widget _buildDeleteBackground(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.error,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerRight,
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    final firestore = FirestoreService();
    final start = _rangeStart(_selectedMonth);
    final end = _rangeEnd(_selectedMonth);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            MonthYearPicker(
              year: _selectedMonth.year,
              month: _selectedMonth.month,
              onChanged: (value) {
                setState(() => _selectedMonth = DateTime(value.year, value.month, 1));
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<CategoryModel>>(
                stream: firestore.streamCategories(user.uid),
                builder: (context, catSnap) {
                  final categories = catSnap.data ?? const <CategoryModel>[];
                  final byId = <String, CategoryModel>{for (final c in categories) c.id: c};

                  return StreamBuilder<List<TransactionModel>>(
                    stream: firestore.streamTransactions(
                      user.uid,
                      start: start,
                      end: end,
                    ),
                    builder: (context, txSnap) {
                      if (txSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final txs = txSnap.data ?? const <TransactionModel>[];
                      if (txs.isEmpty) {
                        return Center(
                          child: Card(
                            margin: const EdgeInsets.all(24),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 40,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No expenses in this month',
                                    style: Theme.of(context).textTheme.titleMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pick another month or add a new expense.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: txs.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 0),
                        itemBuilder: (context, index) {
                          final tx = txs[index];
                          return Dismissible(
                            key: ValueKey(tx.id),
                            direction: DismissDirection.endToStart,
                            background: _buildDeleteBackground(context),
                            onDismissed: (_) async {
                              await firestore.deleteTransaction(user.uid, tx.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Expense deleted')),
                              );
                            },
                            child: TransactionTile(
                              tx: tx,
                              category: byId[tx.categoryId],
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EditTransactionPage(
                                      uid: user.uid,
                                      existing: tx,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
