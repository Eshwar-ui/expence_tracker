import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/budget.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Get budgets collection reference (under user)
  CollectionReference get _budgetsCollection {
    if (_userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(_userId).collection('budgets');
  }

  // Get budget_plans collection reference (under user)
  CollectionReference get _budgetPlansCollection {
    if (_userId == null) throw Exception('User not authenticated');
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('budget_plans');
  }

  // Create or update budget plan
  Future<void> saveBudgetPlan(BudgetPlan budgetPlan) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      await _budgetPlansCollection.doc('plan').set(budgetPlan.toMap());
    } catch (e) {
      throw Exception('Failed to save budget plan: $e');
    }
  }

  // Get user's budget plan
  Future<BudgetPlan?> getBudgetPlan() async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      final doc = await _budgetPlansCollection.doc('plan').get();

      if (!doc.exists) return null;

      return BudgetPlan.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to get budget plan: $e');
    }
  }

  // Create new budget
  Future<void> createBudget(Budget budget) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      await _budgetsCollection.doc(budget.id).set(budget.toMap());
    } catch (e) {
      throw Exception('Failed to create budget: $e');
    }
  }

  // Update budget
  Future<void> updateBudget(Budget budget) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      await _budgetsCollection.doc(budget.id).update(budget.toMap());
    } catch (e) {
      throw Exception('Failed to update budget: $e');
    }
  }

  // Delete budget
  Future<void> deleteBudget(String budgetId) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      await _budgetsCollection.doc(budgetId).delete();
    } catch (e) {
      throw Exception('Failed to delete budget: $e');
    }
  }

  // Get all budgets for user
  Future<List<Budget>> getBudgets() async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      final querySnapshot = await _budgetsCollection.get();

      return querySnapshot.docs
          .map((doc) => Budget.fromMap(doc.data() as Map<String, dynamic>))
          .where((budget) => budget.isActive)
          .toList();
    } catch (e) {
      throw Exception('Failed to get budgets: $e');
    }
  }

  // Calculate spent amount for a category from transactions
  Future<double> calculateSpentForCategory(
    String category,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('expenses')
          .get();

      double totalSpent = 0.0;
      for (final doc in querySnapshot.docs) {
        final expense = _expenseFromDoc(doc.data());

        if (expense.category.toLowerCase() == category.toLowerCase() &&
            expense.type == 'expense' &&
            !expense.date.isBefore(startDate) &&
            !expense.date.isAfter(endDate)) {
          totalSpent += expense.amount;
        }
      }
      return totalSpent;
    } catch (e) {
      throw Exception('Failed to calculate spent amount: $e');
    }
  }

  // Update budget spent amounts based on transactions
  Future<void> updateBudgetSpentAmounts() async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      final budgets = await getBudgets();
      if (budgets.isEmpty) return;

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Fetch all expenses for the current month once
      final querySnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('expenses')
          .where('type', isEqualTo: 'expense')
          // Using String comparison if dates are stored as ISO Strings
          .get();

      final categorySpent = <String, double>{};
      for (final doc in querySnapshot.docs) {
        final expense = _expenseFromDoc(doc.data());
        if (expense.date.isBefore(startOfMonth)) continue;

        categorySpent[expense.category.toLowerCase()] =
            (categorySpent[expense.category.toLowerCase()] ?? 0.0) +
                expense.amount;
      }

      for (final budget in budgets) {
        final spent = categorySpent[budget.category.toLowerCase()] ?? 0.0;

        if ((spent - budget.spent).abs() > 0.01) {
          await updateBudget(budget.copyWith(spent: spent, updatedAt: now));
        }
      }
    } catch (e) {
      debugPrint('Failed to update budget spent amounts: $e');
      // Non-blocking failure
    }
  }

  // Get budget analytics
  Future<Map<String, dynamic>> getBudgetAnalytics() async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      final budgets = await getBudgets();
      final budgetPlan = await getBudgetPlan();

      if (budgets.isEmpty) {
        return {
          'totalBudgeted': 0.0,
          'totalSpent': 0.0,
          'remaining': 0.0,
          'monthlyIncome': budgetPlan?.monthlyIncome ?? 0.0,
          'savingsTarget': budgetPlan?.savingsTarget ?? 0.0,
          'budgetStatus': 'No budgets set',
          'exceededBudgets': <String>[],
          'nearLimitBudgets': <String>[],
        };
      }

      final totalBudgeted = budgets.fold(
        0.0,
        (acc, budget) => acc + budget.limit,
      );
      final totalSpent =
          budgets.fold(0.0, (acc, budget) => acc + budget.spent);
      final remaining = totalBudgeted - totalSpent;

      final exceededBudgets = budgets
          .where((budget) => budget.status == BudgetStatus.exceeded)
          .map((budget) => budget.category)
          .toList();

      final nearLimitBudgets = budgets
          .where((budget) => budget.status == BudgetStatus.nearLimit)
          .map((budget) => budget.category)
          .toList();

      String budgetStatusText = 'On Track';
      if (exceededBudgets.isNotEmpty) {
        budgetStatusText = 'Exceeded';
      } else if (nearLimitBudgets.isNotEmpty) {
        budgetStatusText = 'Near Limit';
      }

      return {
        'totalBudgeted': totalBudgeted,
        'totalSpent': totalSpent,
        'remaining': remaining,
        'monthlyIncome': budgetPlan?.monthlyIncome ?? 0.0,
        'savingsTarget': budgetPlan?.savingsTarget ?? 0.0,
        'budgetStatus': budgetStatusText,
        'exceededBudgets': exceededBudgets,
        'nearLimitBudgets': nearLimitBudgets,
        'budgetCount': budgets.length,
      };
    } catch (e) {
      throw Exception('Failed to get budget analytics: $e');
    }
  }

  // Get common budget categories
  static List<String> getCommonCategories() {
    return [
      'Food & Dining',
      'Transportation',
      'Shopping',
      'Entertainment',
      'Bills & Utilities',
      'Healthcare',
      'Education',
      'Travel',
      'Personal Care',
      'Subscriptions',
      'Insurance',
      'Savings',
      'Investments',
      'Gifts & Donations',
      'Other',
    ];
  }

  // Generate unique ID
  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  BudgetExpenseView _expenseFromDoc(Map<String, dynamic> data) {
    final value = data['date'];
    DateTime date;
    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is String) {
      date = DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is int) {
      date = DateTime.fromMillisecondsSinceEpoch(value);
    } else {
      date = DateTime.now();
    }

    return BudgetExpenseView(
      category: data['category'] as String? ?? 'Other',
      type: data['type'] as String? ?? 'expense',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: date,
    );
  }
}

class BudgetExpenseView {
  final String category;
  final String type;
  final double amount;
  final DateTime date;

  const BudgetExpenseView({
    required this.category,
    required this.type,
    required this.amount,
    required this.date,
  });
}
