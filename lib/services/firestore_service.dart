import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';

/// Thin Firestore data-access layer using the schema:
/// `users/{uid}/categories/*` and `users/{uid}/transactions/*`.
class FirestoreService {
  final FirebaseFirestore _db;

  static const int _defaultCategoriesVersion = 2;
  static const _recurringIntervals = {'monthly', 'yearly'};

  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _categoriesRef(String uid) =>
      _userDoc(uid).collection('categories');

  CollectionReference<Map<String, dynamic>> _transactionsRef(String uid) =>
      _userDoc(uid).collection('transactions');

  String newTransactionId(String uid) => _transactionsRef(uid).doc().id;

  Stream<List<CategoryModel>> streamCategories(String uid) {
    return _categoriesRef(uid)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(CategoryModel.fromDoc).toList());
  }

  Future<void> addCategory(String uid, CategoryModel category) async {
    await _categoriesRef(uid).add(category.toMap());
  }

  Future<void> updateCategory(String uid, String id, CategoryModel category) async {
    await _categoriesRef(uid).doc(id).update(category.toMap());
  }

  Future<void> deleteCategory(String uid, String id) async {
    await _categoriesRef(uid).doc(id).delete();
  }

  Stream<List<TransactionModel>> streamTransactions(
    String uid, {
    DateTime? start,
    DateTime? end,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _transactionsRef(uid);

    if (start != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    }
    if (end != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(end),
      );
    }

    query = query.orderBy('date', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query
        .snapshots()
        .map((snap) => snap.docs.map(TransactionModel.fromDoc).toList());
  }

  Future<List<TransactionModel>> fetchTransactions(
    String uid, {
    DateTime? start,
    DateTime? end,
  }) async {
    Query<Map<String, dynamic>> query = _transactionsRef(uid);

    if (start != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    }
    if (end != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(end),
      );
    }

    query = query.orderBy('date', descending: true);

    final snap = await query.get();
    return snap.docs.map(TransactionModel.fromDoc).toList();
  }

  Future<void> addTransaction(String uid, TransactionModel tx) async {
    final doc = _transactionsRef(uid).doc();
    await doc.set({
      ...tx.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addTransactionWithId(String uid, String id, TransactionModel tx) async {
    await _transactionsRef(uid).doc(id).set({
      ...tx.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTransaction(String uid, String id, TransactionModel tx) async {
    await _transactionsRef(uid).doc(id).update(tx.toMap());
  }

  Future<void> deleteTransaction(String uid, String id) async {
    await _transactionsRef(uid).doc(id).delete();
  }

  Future<void> ensureRecurringTransactions(String uid) async {
    final now = DateTime.now();
    final templatesSnap =
        await _transactionsRef(uid).where('recurringEnabled', isEqualTo: true).get();

    for (final doc in templatesSnap.docs) {
      final template = TransactionModel.fromDoc(doc);
      if (template.recurringParentId != null) {
        continue;
      }
      if (!_recurringIntervals.contains(template.recurringInterval)) {
        continue;
      }

      var lastDate = template.recurringLastDate ?? template.date;

      var nextDate = _nextRecurringDate(lastDate, template.recurringInterval!);
      var generated = false;
      while (!nextDate.isAfter(now)) {
        final instance = template.copyWith(
          id: '',
          date: nextDate,
          createdAt: null,
          recurringEnabled: false,
          recurringInterval: null,
          recurringParentId: template.id,
          recurringLastDate: null,
        );
        await addTransaction(uid, instance);
        lastDate = nextDate;
        nextDate = _nextRecurringDate(lastDate, template.recurringInterval!);
        generated = true;
      }

      if (generated) {
        await _transactionsRef(uid).doc(template.id).update({
          'recurringLastDate': Timestamp.fromDate(lastDate),
        });
      }
    }
  }

  DateTime _nextRecurringDate(DateTime from, String interval) {
    switch (interval) {
      case 'monthly':
        return _addMonthsClamped(from, 1);
      case 'yearly':
        return _addMonthsClamped(from, 12);
      default:
        return _addMonthsClamped(from, 1);
    }
  }

  DateTime _addMonthsClamped(DateTime from, int monthsToAdd) {
    final year = from.year + ((from.month - 1 + monthsToAdd) ~/ 12);
    final month = ((from.month - 1 + monthsToAdd) % 12) + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = from.day > lastDay ? lastDay : from.day;
    return DateTime(
      year,
      month,
      day,
      from.hour,
      from.minute,
      from.second,
      from.millisecond,
      from.microsecond,
    );
  }

  Future<void> ensureDefaultCategories(String uid) async {
    // Safe to call on login: upgrades default categories at most once per version.
    final userDoc = _userDoc(uid);
    final userSnap = await userDoc.get();
    final userData = userSnap.data();
    final currentVersion = (userData?['defaultCategoriesVersion'] as num?)?.toInt() ?? 0;
    if (currentVersion >= _defaultCategoriesVersion) return;

    final defaultNames = <String>[
      'שכר דירה וארנונה',
      'תחבורה ציבורית',
      'הוצאות רפואיות',
      'מצרכי מזון',
      'מצרכים זבל',
      'טיפוח עצמי',
      'חשבון חשמל',
      'חשבון אינטרנט',
      'חבילת סלולרי',
      'חשבון גז',
      'חשבון מים',
      'קנסות',
      'דוחות תנועה',
      'מיסים אחרים',
      'כלים וחומרי עבודה',
      'קורסים',
      'מוצרי חיות מחמד',
      'מנויים לשירותים אינטרנטיים',
      'אוכל חיות',
      'הוצאות על הרכב',
      'סרטים/הופעות/ספרים',
      'חניה',
      'טבק /אלכוהול',
      'יציאת בילוי',
      'ביגוד ותכשיטים',
      'ריהוט',
      'מונית',
      'מוצרי חשמל וגאדג׳טים',
      'מתנות/תרומות',
      'אוכל במסעדה',
      'אוכל מהיר',
      'שונות',
      'עמלות בנק וכספומטים',
    ];

    String categoryIdFromName(String name) {
      final out = StringBuffer();
      var lastUnderscore = false;

      for (final rune in name.runes) {
        final isLatinUpper = rune >= 0x41 && rune <= 0x5A;
        final isLatinLower = rune >= 0x61 && rune <= 0x7A;
        final isDigit = rune >= 0x30 && rune <= 0x39;
        final isHebrew = rune >= 0x0590 && rune <= 0x05FF;
        final isAllowed = isLatinUpper || isLatinLower || isDigit || isHebrew;

        if (isAllowed) {
          out.writeCharCode(rune);
          lastUnderscore = false;
        } else if (!lastUnderscore) {
          out.write('_');
          lastUnderscore = true;
        }
      }

      var id = out.toString();
      while (id.startsWith('_')) {
        id = id.substring(1);
      }
      while (id.endsWith('_')) {
        id = id.substring(0, id.length - 1);
      }
      return id.isEmpty ? 'category' : id;
    }

    final existing = await _categoriesRef(uid).get();
    final existingIds = existing.docs.map((d) => d.id).toSet();

    final batch = _db.batch();
    for (var i = 0; i < defaultNames.length; i++) {
      final name = defaultNames[i];
      final id = categoryIdFromName(name);
      if (existingIds.contains(id)) continue;
      batch.set(
        _categoriesRef(uid).doc(id),
        CategoryModel(id: id, name: name, order: i).toMap(),
      );
    }

    batch.set(
      userDoc,
      {'defaultCategoriesVersion': _defaultCategoriesVersion},
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}
