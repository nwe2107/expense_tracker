import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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

class _ExpensesTabState extends State<ExpensesTab> with AutomaticKeepAliveClientMixin {
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

  @override
  bool get wantKeepAlive => true;

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Expense'),
            content: const Text('Are you sure you want to delete this expense?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteExpense(
    BuildContext context,
    TransactionModel tx,
    FirestoreService firestore,
    String uid,
  ) async {
    // 1. Delete from DB (keep receipt for now)
    await firestore.deleteTransaction(uid, tx.id, keepReceipt: true);

    if (!context.mounted) return;

    // 2. Show Snackbar
    ScaffoldMessenger.of(context).clearSnackBars();
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Expense deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Restore
            firestore.addTransactionWithId(uid, tx.id, tx);
          },
        ),
      ),
    );

    // 3. Handle Receipt Cleanup
    final reason = await controller.closed;
    if (reason != SnackBarClosedReason.action) {
      // User didn't undo. Delete receipt if exists.
      if (tx.receiptUrl != null && tx.receiptUrl!.isNotEmpty) {
        await firestore.deleteReceipt(tx.receiptUrl!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                          return Slidable(
                            key: ValueKey(tx.id),
                            endActionPane: ActionPane(
                              motion: const ScrollMotion(),
                              extentRatio: 0.25,
                              dismissible: DismissiblePane(
                                onDismissed: () {
                                  _deleteExpense(context, tx, firestore, user.uid);
                                },
                                confirmDismiss: () => _confirmDelete(context),
                                closeOnCancel: true,
                              ),
                              children: [
                                SlidableAction(
                                  onPressed: (slidableContext) async {
                                    final confirmed = await _confirmDelete(context);
                                    if (confirmed && context.mounted) {
                                      await _deleteExpense(
                                        context,
                                        tx,
                                        firestore,
                                        user.uid,
                                      );
                                    }
                                  },
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete,
                                ),
                              ],
                            ),
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
