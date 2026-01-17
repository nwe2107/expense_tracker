import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import 'categories_page.dart';
import 'edit_transaction_page.dart';
import 'reports_page.dart';
import '../widgets/transaction_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirestoreService _firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _firestore.ensureDefaultCategories(uid);
    }
  }

  DateTime _startOfMonth(DateTime now) => DateTime(now.year, now.month, 1);

  DateTime _endOfMonth(DateTime now) =>
      DateTime(now.year, now.month + 1, 1).subtract(const Duration(microseconds: 1));

  double _sumAmounts(List<TransactionModel> txs) {
    double total = 0;
    for (final tx in txs) {
      total += tx.amount;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    final now = DateTime.now();
    final monthStart = _startOfMonth(now);
    final monthEnd = _endOfMonth(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SafeArea(
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
                  final total = _sumAmounts(snapshot.data ?? const <TransactionModel>[]);
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
                          Text(
                            '₪ ${total.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EditTransactionPage(uid: user.uid),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Expense'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CategoriesPage(uid: user.uid),
                        ),
                      );
                    },
                    icon: const Icon(Icons.category_outlined),
                    label: const Text('Categories'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReportsPage(uid: user.uid),
                        ),
                      );
                    },
                    icon: const Icon(Icons.pie_chart_outline),
                    label: const Text('Reports'),
                  ),
                ],
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
                          return const Center(child: Text('No expenses yet. Tap “Add Expense”.'));
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
      ),
    );
  }
}
