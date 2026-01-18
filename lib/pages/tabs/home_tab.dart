import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/currency_data.dart';
import '../edit_transaction_page.dart';
import '../../widgets/transaction_tile.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final FirestoreService _firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _firestore.ensureDefaultCategories(uid);
      _firestore.ensureRecurringTransactions(uid);
    }
  }

  DateTime _startOfMonth(DateTime now) => DateTime(now.year, now.month, 1);

  DateTime _endOfMonth(DateTime now) =>
      DateTime(now.year, now.month + 1, 1).subtract(const Duration(microseconds: 1));

  Map<String, double> _totalsByCurrency(List<TransactionModel> txs) {
    final totals = <String, double>{};
    for (final tx in txs) {
      totals[tx.currency] = (totals[tx.currency] ?? 0) + tx.amount;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    final now = DateTime.now();
    final monthStart = _startOfMonth(now);
    final monthEnd = _endOfMonth(now);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<List<TransactionModel>>(
              stream: _firestore.streamTransactions(
                user.uid,
                start: monthStart,
                end: monthEnd,
              ),
              builder: (context, snapshot) {
                final totals = _totalsByCurrency(
                  snapshot.data ?? const <TransactionModel>[],
                );
                final codes = totals.keys.toList()..sort();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This month',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (codes.isEmpty)
                          Text(
                            'No expenses yet.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        else
                          ...codes.map((code) {
                            final currency = currencyOptionByCode(code);
                            return Text(
                              '${currency.symbol} ${totals[code]!.toStringAsFixed(2)} (${currency.code})',
                              style: Theme.of(context).textTheme.displaySmall,
                            );
                          }),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Recent',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<CategoryModel>>(
                stream: _firestore.streamCategories(user.uid),
                builder: (context, catSnap) {
                  final categories = catSnap.data ?? const <CategoryModel>[];
                  final byId = <String, CategoryModel>{
                    for (final c in categories) c.id: c,
                  };

                  return StreamBuilder<List<TransactionModel>>(
                    stream: _firestore.streamTransactions(user.uid, limit: 20),
                    builder: (context, txSnap) {
                      if (txSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final txs = txSnap.data ?? const <TransactionModel>[];
                      if (txs.isEmpty) {
                        return const Center(child: Text('No expenses yet. Tap + to add.'));
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
          ],
        ),
      ),
    );
  }
}
