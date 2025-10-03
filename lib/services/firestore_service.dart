import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expence.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  // Get expenses collection reference
  CollectionReference get _expensesCollection {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore.collection('users').doc(_userId).collection('expenses');
  }

  // Add a new expense to Firestore
  Future<void> addExpense(Expense expense) async {
    try {
      await _expensesCollection.doc(expense.id).set(expense.toJson());
    } catch (e) {
      throw Exception('Failed to add expense: $e');
    }
  }

  // Get all expenses from Firestore
  Future<List<Expense>> getExpenses() async {
    try {
      final snapshot = await _expensesCollection
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Expense.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to load expenses: $e');
    }
  }

  // Update an existing expense
  Future<void> updateExpense(Expense expense) async {
    try {
      await _expensesCollection.doc(expense.id).update(expense.toJson());
    } catch (e) {
      throw Exception('Failed to update expense: $e');
    }
  }

  // Delete an expense
  Future<void> deleteExpense(String expenseId) async {
    try {
      await _expensesCollection.doc(expenseId).delete();
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }

  // Get expenses by category
  Future<List<Expense>> getExpensesByCategory(String category) async {
    try {
      final snapshot = await _expensesCollection
          .where('category', isEqualTo: category)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Expense.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to filter expenses by category: $e');
    }
  }

  // Get expenses for a specific date range
  Future<List<Expense>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final snapshot = await _expensesCollection
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Expense.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to filter expenses by date range: $e');
    }
  }

  // Get total amount for all expenses
  Future<double> getTotalAmount() async {
    try {
      final expenses = await getExpenses();
      return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
    } catch (e) {
      throw Exception('Failed to calculate total amount: $e');
    }
  }

  // Get total amount by category
  Future<double> getTotalAmountByCategory(String category) async {
    try {
      final expenses = await getExpensesByCategory(category);
      return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
    } catch (e) {
      throw Exception('Failed to calculate total amount by category: $e');
    }
  }

  // Get expenses stream for real-time updates
  Stream<List<Expense>> getExpensesStream() {
    return _expensesCollection
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Expense.fromJson(data);
          }).toList();
        });
  }

  // Get expenses by category stream
  Stream<List<Expense>> getExpensesByCategoryStream(String category) {
    return _expensesCollection
        .where('category', isEqualTo: category)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Expense.fromJson(data);
          }).toList();
        });
  }

  // Clear all expenses (for testing or reset functionality)
  Future<void> clearAllExpenses() async {
    try {
      final snapshot = await _expensesCollection.get();
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to clear expenses: $e');
    }
  }

  // Get expense statistics
  Future<Map<String, dynamic>> getExpenseStatistics() async {
    try {
      final expenses = await getExpenses();

      if (expenses.isEmpty) {
        return {
          'totalAmount': 0.0,
          'totalCount': 0,
          'categoryBreakdown': <String, double>{},
          'monthlyBreakdown': <String, double>{},
        };
      }

      // Calculate category breakdown
      final categoryBreakdown = <String, double>{};
      for (final expense in expenses) {
        categoryBreakdown[expense.category] =
            (categoryBreakdown[expense.category] ?? 0.0) + expense.amount;
      }

      // Calculate monthly breakdown
      final monthlyBreakdown = <String, double>{};
      for (final expense in expenses) {
        final monthKey =
            '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';
        monthlyBreakdown[monthKey] =
            (monthlyBreakdown[monthKey] ?? 0.0) + expense.amount;
      }

      return {
        'totalAmount': expenses.fold<double>(
          0.0,
          (sum, expense) => sum + expense.amount,
        ),
        'totalCount': expenses.length,
        'categoryBreakdown': categoryBreakdown,
        'monthlyBreakdown': monthlyBreakdown,
      };
    } catch (e) {
      throw Exception('Failed to calculate statistics: $e');
    }
  }
}
