import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/transaction_tile.dart';
import '../edit_transaction_page.dart';

class ExpensesTab extends StatelessWidget {
  const ExpensesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    final firestore = FirestoreService();

    // Simple all-transactions list for the Expenses tab.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<CategoryModel>>(
          stream: firestore.streamCategories(user.uid),
          builder: (context, catSnap) {
            final categories = catSnap.data ?? const <CategoryModel>[];
            final byId = <String, CategoryModel>{for (final c in categories) c.id: c};

            return StreamBuilder<List<TransactionModel>>(
              stream: firestore.streamTransactions(user.uid),
              builder: (context, txSnap) {
                if (txSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final txs = txSnap.data ?? const <TransactionModel>[];
                if (txs.isEmpty) {
                  // Empty state for brand new accounts.
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
                              'No expenses yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap + to add your first expense.',
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
                  separatorBuilder: (context, index) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final tx = txs[index];
                    return TransactionTile(
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
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
