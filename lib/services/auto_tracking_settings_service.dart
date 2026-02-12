import 'package:shared_preferences/shared_preferences.dart';

class AutoTrackingSettingsService {
  static const String _enabledKey = 'auto_tracking_enabled';
  static const String _needsReviewKey = 'auto_tracking_needs_review_count';
  static const String _lastExpenseIdKey = 'auto_tracking_last_expense_id';
  static const String _lastDuplicateKeyKey = 'auto_tracking_last_duplicate_key';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<int> getNeedsReviewCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_needsReviewKey) ?? 0;
  }

  Future<void> setNeedsReviewCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_needsReviewKey, count < 0 ? 0 : count);
  }

  Future<void> incrementNeedsReview() async {
    final current = await getNeedsReviewCount();
    await setNeedsReviewCount(current + 1);
  }

  Future<void> decrementNeedsReview() async {
    final current = await getNeedsReviewCount();
    await setNeedsReviewCount(current - 1);
  }

  Future<void> setLastAutoInsert(String expenseId, String duplicateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastExpenseIdKey, expenseId);
    await prefs.setString(_lastDuplicateKeyKey, duplicateKey);
  }

  Future<String?> getLastExpenseId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastExpenseIdKey);
  }

  Future<String?> getLastDuplicateKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastDuplicateKeyKey);
  }

  Future<void> clearLastAutoInsert() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastExpenseIdKey);
    await prefs.remove(_lastDuplicateKeyKey);
  }
}
