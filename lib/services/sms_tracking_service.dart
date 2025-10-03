import 'package:shared_preferences/shared_preferences.dart';

class SMSTrackingService {
  static const String _addedTransactionsKey = 'added_sms_transactions';

  // Add a transaction ID to the list of added transactions
  Future<void> markTransactionAsAdded(String transactionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addedTransactions = await getAddedTransactionIds();
      addedTransactions.add(transactionId);

      await prefs.setStringList(
        _addedTransactionsKey,
        addedTransactions.toList(),
      );
    } catch (e) {
      throw Exception('Failed to mark transaction as added: $e');
    }
  }

  // Get all transaction IDs that have been added to expenses
  Future<Set<String>> getAddedTransactionIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionIds = prefs.getStringList(_addedTransactionsKey) ?? [];
      return transactionIds.toSet();
    } catch (e) {
      throw Exception('Failed to get added transaction IDs: $e');
    }
  }

  // Check if a specific transaction has been added
  Future<bool> isTransactionAdded(String transactionId) async {
    try {
      final addedTransactions = await getAddedTransactionIds();
      return addedTransactions.contains(transactionId);
    } catch (e) {
      throw Exception('Failed to check if transaction is added: $e');
    }
  }

  // Remove a transaction from the added list (if needed)
  Future<void> markTransactionAsNotAdded(String transactionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addedTransactions = await getAddedTransactionIds();
      addedTransactions.remove(transactionId);

      await prefs.setStringList(
        _addedTransactionsKey,
        addedTransactions.toList(),
      );
    } catch (e) {
      throw Exception('Failed to mark transaction as not added: $e');
    }
  }

  // Clear all added transaction records (for testing or reset)
  Future<void> clearAllAddedTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_addedTransactionsKey);
    } catch (e) {
      throw Exception('Failed to clear added transactions: $e');
    }
  }

  // Get count of added transactions
  Future<int> getAddedTransactionCount() async {
    try {
      final addedTransactions = await getAddedTransactionIds();
      return addedTransactions.length;
    } catch (e) {
      throw Exception('Failed to get added transaction count: $e');
    }
  }
}
