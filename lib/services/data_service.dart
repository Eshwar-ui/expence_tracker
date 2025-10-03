import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/expence.dart';

class DataService {
  static const String _expensesKey = 'expenses';

  // Add a new expense to shared preferences
  Future<void> addExpense(Expense expense) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> expensesList = prefs.getStringList(_expensesKey) ?? [];
      expensesList.add(jsonEncode(expense.toJson()));
      await prefs.setStringList(_expensesKey, expensesList);
    } catch (e) {
      throw Exception('Failed to add expense: $e');
    }
  }

  // Get all expenses from shared preferences
  Future<List<Expense>> getExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> expensesList = prefs.getStringList(_expensesKey) ?? [];
      return expensesList.map((e) {
        final data = jsonDecode(e);
        return Expense.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to load expenses: $e');
    }
  }

  // Update an existing expense
  Future<void> updateExpense(Expense expense) async {
    try {
      final expenses = await getExpenses();
      final index = expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        expenses[index] = expense;
        await _saveExpenses(expenses);
      }
    } catch (e) {
      throw Exception('Failed to update expense: $e');
    }
  }

  // Delete an expense
  Future<void> deleteExpense(String expenseId) async {
    try {
      final expenses = await getExpenses();
      expenses.removeWhere((e) => e.id == expenseId);
      await _saveExpenses(expenses);
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }

  // Get expenses by category
  Future<List<Expense>> getExpensesByCategory(String category) async {
    try {
      final expenses = await getExpenses();
      return expenses.where((e) => e.category == category).toList();
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
      final expenses = await getExpenses();
      return expenses
          .where(
            (e) =>
                e.date.isAfter(start.subtract(const Duration(days: 1))) &&
                e.date.isBefore(end.add(const Duration(days: 1))),
          )
          .toList();
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

  // Private method to save expenses list
  Future<void> _saveExpenses(List<Expense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final expensesList = expenses.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_expensesKey, expensesList);
  }

  // Clear all expenses (for testing or reset functionality)
  Future<void> clearAllExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_expensesKey);
    } catch (e) {
      throw Exception('Failed to clear expenses: $e');
    }
  }
}
