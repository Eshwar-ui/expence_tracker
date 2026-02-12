import 'package:shared_preferences/shared_preferences.dart';

class NotificationTrackingService {
  static const String _addedNotificationsKey = 'added_notification_transactions';

  Future<void> markTransactionAsAdded(String transactionKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final added = await getAddedTransactionKeys();
      added.add(transactionKey);
      await prefs.setStringList(_addedNotificationsKey, added.toList());
    } catch (e) {
      throw Exception('Failed to mark notification as added: $e');
    }
  }

  Future<void> markTransactionAsNotAdded(String transactionKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final added = await getAddedTransactionKeys();
      added.remove(transactionKey);
      await prefs.setStringList(_addedNotificationsKey, added.toList());
    } catch (e) {
      throw Exception('Failed to rollback notification mark: $e');
    }
  }

  Future<Set<String>> getAddedTransactionKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getStringList(_addedNotificationsKey) ?? <String>[];
      return keys.toSet();
    } catch (e) {
      throw Exception('Failed to load notification tracking keys: $e');
    }
  }

  Future<bool> isTransactionAdded(String transactionKey) async {
    try {
      final added = await getAddedTransactionKeys();
      return added.contains(transactionKey);
    } catch (e) {
      throw Exception('Failed to check notification tracking key: $e');
    }
  }
}
