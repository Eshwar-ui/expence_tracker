import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recurring_transaction.dart';
import '../models/expence.dart';
import '../services/firestore_service.dart';

class RecurringTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  String? get _userId => _auth.currentUser?.uid;

  // Create recurring transaction
  Future<void> createRecurringTransaction(
    RecurringTransaction transaction,
  ) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      await _firestore
          .collection('recurring_transactions')
          .doc(transaction.id)
          .set(transaction.toMap());
    } catch (e) {
      throw Exception('Failed to create recurring transaction: $e');
    }
  }

  // Update recurring transaction
  Future<void> updateRecurringTransaction(
    RecurringTransaction transaction,
  ) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      await _firestore
          .collection('recurring_transactions')
          .doc(transaction.id)
          .update(transaction.toMap());
    } catch (e) {
      throw Exception('Failed to update recurring transaction: $e');
    }
  }

  // Delete recurring transaction
  Future<void> deleteRecurringTransaction(String transactionId) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      await _firestore
          .collection('recurring_transactions')
          .doc(transactionId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete recurring transaction: $e');
    }
  }

  // Get all recurring transactions for user
  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      final querySnapshot = await _firestore
          .collection('recurring_transactions')
          .where('userId', isEqualTo: _userId)
          .where('isActive', isEqualTo: true)
          .orderBy('title')
          .get();

      return querySnapshot.docs
          .map((doc) => RecurringTransaction.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get recurring transactions: $e');
    }
  }

  // Execute recurring transactions that are due
  Future<List<Expense>> executeDueTransactions() async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      final recurringTransactions = await getRecurringTransactions();
      final executedTransactions = <Expense>[];

      for (final recurringTransaction in recurringTransactions) {
        if (recurringTransaction.shouldExecuteToday()) {
          final expense = Expense(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: recurringTransaction.title,
            amount: recurringTransaction.amount,
            date: DateTime.now(),
            category: recurringTransaction.category,
            description: recurringTransaction.description,
            type: TransactionType
                .expense, // Most recurring transactions are expenses
          );

          // Add to expenses
          await _firestoreService.addExpense(expense);

          // Update last executed date
          await updateRecurringTransaction(
            recurringTransaction.copyWith(
              lastExecuted: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          executedTransactions.add(expense);
        }
      }

      return executedTransactions;
    } catch (e) {
      throw Exception('Failed to execute due transactions: $e');
    }
  }

  // Get common recurring transaction templates
  static List<Map<String, dynamic>> getCommonTemplates() {
    return [
      {
        'title': 'Rent',
        'description': 'Monthly rent payment',
        'category': 'Housing',
        'frequency': RecurringFrequency.monthly,
        'amount': 15000.0,
      },
      {
        'title': 'Electricity Bill',
        'description': 'Monthly electricity bill',
        'category': 'Bills & Utilities',
        'frequency': RecurringFrequency.monthly,
        'amount': 2000.0,
      },
      {
        'title': 'Internet Bill',
        'description': 'Monthly internet subscription',
        'category': 'Bills & Utilities',
        'frequency': RecurringFrequency.monthly,
        'amount': 1000.0,
      },
      {
        'title': 'Gym Membership',
        'description': 'Monthly gym membership fee',
        'category': 'Health & Fitness',
        'frequency': RecurringFrequency.monthly,
        'amount': 2000.0,
      },
      {
        'title': 'Netflix Subscription',
        'description': 'Monthly Netflix subscription',
        'category': 'Entertainment',
        'frequency': RecurringFrequency.monthly,
        'amount': 500.0,
      },
      {
        'title': 'Salary',
        'description': 'Monthly salary',
        'category': 'Income',
        'frequency': RecurringFrequency.monthly,
        'amount': 50000.0,
      },
      {
        'title': 'EMI Payment',
        'description': 'Monthly EMI payment',
        'category': 'Loans',
        'frequency': RecurringFrequency.monthly,
        'amount': 8000.0,
      },
      {
        'title': 'Insurance Premium',
        'description': 'Monthly insurance premium',
        'category': 'Insurance',
        'frequency': RecurringFrequency.monthly,
        'amount': 1500.0,
      },
    ];
  }

  // Generate unique ID
  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Get frequency options for dropdown
  static List<Map<String, dynamic>> getFrequencyOptions() {
    return RecurringFrequency.values.map((frequency) {
      String displayText;
      switch (frequency) {
        case RecurringFrequency.daily:
          displayText = 'Daily';
          break;
        case RecurringFrequency.weekly:
          displayText = 'Weekly';
          break;
        case RecurringFrequency.monthly:
          displayText = 'Monthly';
          break;
        case RecurringFrequency.yearly:
          displayText = 'Yearly';
          break;
      }

      return {'value': frequency, 'text': displayText};
    }).toList();
  }

  // Get common categories for recurring transactions
  static List<String> getCommonCategories() {
    return [
      'Housing',
      'Bills & Utilities',
      'Transportation',
      'Food & Dining',
      'Health & Fitness',
      'Entertainment',
      'Insurance',
      'Loans',
      'Income',
      'Savings',
      'Investments',
      'Subscriptions',
      'Other',
    ];
  }
}
