import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/models/transaction_sms.dart';
import 'package:expence_tracker/services/firestore_service.dart';

/// Service to handle deduplication of SMS transactions against manual entries
class TransactionDeduplicationService {
  final FirestoreService _firestoreService = FirestoreService();

  /// Check if an SMS transaction already exists as a manual entry
  ///
  /// Matching criteria:
  /// - Amount matches exactly
  /// - Date is within the same day
  /// - Transaction type matches (debit/credit -> expense/income)
  ///
  /// Returns the matching expense if found, null otherwise
  Future<Expense?> findDuplicateManualEntry(
      TransactionSMS smsTransaction) async {
    try {
      // Get all expenses for the same day
      final startOfDay = DateTime(
        smsTransaction.date.year,
        smsTransaction.date.month,
        smsTransaction.date.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final expenses = await _firestoreService.getExpensesByDateRange(
        startOfDay,
        endOfDay,
      );

      // Determine the expected transaction type
      final expectedType = smsTransaction.transactionType == 'credit'
          ? TransactionType.income
          : TransactionType.expense;

      // Find matching transaction
      for (final expense in expenses) {
        // Check if amount matches (with small tolerance for floating point)
        final amountMatches =
            (expense.amount - smsTransaction.amount).abs() < 0.01;

        // Check if type matches
        final typeMatches = expense.type == expectedType;

        // Check if it's on the same day
        final dateMatches = expense.date.year == smsTransaction.date.year &&
            expense.date.month == smsTransaction.date.month &&
            expense.date.day == smsTransaction.date.day;

        if (amountMatches && typeMatches && dateMatches) {
          print(
            '🔍 Found duplicate manual entry: ${expense.title} - ₹${expense.amount} on ${expense.date}',
          );
          return expense;
        }
      }

      return null;
    } catch (e) {
      print('❌ Error checking for duplicate: $e');
      return null;
    }
  }

  /// Filter out SMS transactions that already exist as manual entries
  ///
  /// Returns a list of SMS transactions that don't have matching manual entries
  Future<List<TransactionSMS>> filterOutDuplicates(
    List<TransactionSMS> smsTransactions,
  ) async {
    final uniqueTransactions = <TransactionSMS>[];
    int duplicateCount = 0;

    for (final smsTransaction in smsTransactions) {
      final duplicate = await findDuplicateManualEntry(smsTransaction);

      if (duplicate == null) {
        uniqueTransactions.add(smsTransaction);
      } else {
        duplicateCount++;
        print(
          '⏭️  Skipping SMS transaction (already exists): ${smsTransaction.description} - ₹${smsTransaction.amount}',
        );
      }
    }

    print(
      '📊 Deduplication complete: ${uniqueTransactions.length} unique, $duplicateCount duplicates skipped',
    );

    return uniqueTransactions;
  }

  /// Check if a specific SMS transaction is a duplicate
  ///
  /// Returns true if a matching manual entry exists
  Future<bool> isDuplicate(TransactionSMS smsTransaction) async {
    final duplicate = await findDuplicateManualEntry(smsTransaction);
    return duplicate != null;
  }

  /// Get statistics about potential duplicates
  Future<Map<String, dynamic>> getDuplicationStats(
    List<TransactionSMS> smsTransactions,
  ) async {
    int totalTransactions = smsTransactions.length;
    int duplicates = 0;
    int unique = 0;

    for (final smsTransaction in smsTransactions) {
      final isDupe = await isDuplicate(smsTransaction);
      if (isDupe) {
        duplicates++;
      } else {
        unique++;
      }
    }

    return {
      'total': totalTransactions,
      'duplicates': duplicates,
      'unique': unique,
      'duplicationRate': totalTransactions > 0
          ? (duplicates / totalTransactions * 100).toStringAsFixed(1)
          : '0.0',
    };
  }
}
