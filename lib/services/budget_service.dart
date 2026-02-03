import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/budget.dart';
import '../models/expence.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Create or update budget plan
  Future<void> saveBudgetPlan(BudgetPlan budgetPlan) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      await _firestore
          .collection('budget_plans')
          .doc(budgetPlan.id)
          .set(budgetPlan.toMap());
    } catch (e) {
      throw Exception('Failed to save budget plan: $e');
    }
  }

  // Get user's budget plan
  Future<BudgetPlan?> getBudgetPlan() async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      final doc = await _firestore
          .collection('budget_plans')
          .where('userId', isEqualTo: _userId)
          .limit(1)
          .get();

      if (doc.docs.isEmpty) return null;

      return BudgetPlan.fromMap(doc.docs.first.data());
    } catch (e) {
      throw Exception('Failed to get budget plan: $e');
    }
  }

  // Create new budget
  Future<void> createBudget(Budget budget) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      await _firestore.collection('budgets').doc(budget.id).set(budget.toMap());
    } catch (e) {
      throw Exception('Failed to create budget: $e');
    }
  }

  // Update budget
  Future<void> updateBudget(Budget budget) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      await _firestore
          .collection('budgets')
          .doc(budget.id)
          .update(budget.toMap());
    } catch (e) {
      throw Exception('Failed to update budget: $e');
    }
  }

  // Delete budget
  Future<void> deleteBudget(String budgetId) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      await _firestore.collection('budgets').doc(budgetId).delete();
    } catch (e) {
      throw Exception('Failed to delete budget: $e');
    }
  }

  // Get all budgets for user
  Future<List<Budget>> getBudgets() async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      final querySnapshot = await _firestore
          .collection('budgets')
          .where('userId', isEqualTo: _userId)
          .where('isActive', isEqualTo: true)
          .orderBy('category')
          .get();

      return querySnapshot.docs
          .map((doc) => Budget.fromMap(doc.data()))
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
      // Use the correct path: users/{userId}/expenses (subcollection)
      final querySnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('expenses')
          .where('category', isEqualTo: category)
          .where('type', isEqualTo: TransactionType.expense.name)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double totalSpent = 0.0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        totalSpent += (data['amount'] ?? 0).toDouble();
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
      final now = DateTime.now();

      // Calculate start of current month
      final startOfMonth = DateTime(now.year, now.month, 1);

      for (final budget in budgets) {
        final spent = await calculateSpentForCategory(
          budget.category,
          startOfMonth,
          now,
        );

        if (spent != budget.spent) {
          await updateBudget(budget.copyWith(spent: spent, updatedAt: now));
        }
      }
    } catch (e) {
      throw Exception('Failed to update budget spent amounts: $e');
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
        (sum, budget) => sum + budget.limit,
      );
      final totalSpent = budgets.fold(0.0, (sum, budget) => sum + budget.spent);
      final remaining = totalBudgeted - totalSpent;

      final exceededBudgets = budgets
          .where((budget) => budget.status == BudgetStatus.exceeded)
          .map((budget) => budget.category)
          .toList();

      final nearLimitBudgets = budgets
          .where((budget) => budget.status == BudgetStatus.nearLimit)
          .map((budget) => budget.category)
          .toList();

      String budgetStatus = 'On Track';
      if (exceededBudgets.isNotEmpty) {
        budgetStatus = 'Exceeded';
      } else if (nearLimitBudgets.isNotEmpty) {
        budgetStatus = 'Near Limit';
      }

      return {
        'totalBudgeted': totalBudgeted,
        'totalSpent': totalSpent,
        'remaining': remaining,
        'monthlyIncome': budgetPlan?.monthlyIncome ?? 0.0,
        'savingsTarget': budgetPlan?.savingsTarget ?? 0.0,
        'budgetStatus': budgetStatus,
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
}
