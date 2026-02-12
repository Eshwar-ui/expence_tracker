import 'dart:convert';

import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/models/notification_payload.dart';
import 'package:expence_tracker/utils/notification_parsing.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugTestResult {
  final ParsingResult parsing;
  final ValidationResult validation;
  final Expense? expense;

  const DebugTestResult({
    required this.parsing,
    required this.validation,
    required this.expense,
  });
}

class DebugTestNotificationService {
  static const String _entriesKey = 'debug_test_notification_entries';
  static const String _keysKey = 'debug_test_notification_keys';

  Future<DebugTestResult> runTest({
    required String sourceType,
    required String title,
    required String body,
    required int timestamp,
  }) async {
    if (!kDebugMode) {
      return DebugTestResult(
        parsing: const ParsingResult(
          amount: null,
          transactionType: null,
          merchant: null,
          confidence: 0.0,
        ),
        validation: const ValidationResult(
          isValid: false,
          isDuplicate: false,
          isLowConfidence: false,
          reasons: <String>['debug_only'],
        ),
        expense: null,
      );
    }

    final parsing = NotificationParsing.parse(body, title: title);
    final source = 'debug:$sourceType';
    final amount = parsing.amount;

    if (amount == null) {
      return DebugTestResult(
        parsing: parsing,
        validation: const ValidationResult(
          isValid: false,
          isDuplicate: false,
          isLowConfidence: false,
          reasons: <String>['invalid_amount'],
        ),
        expense: null,
      );
    }

    final duplicateKey = NotificationValidation.duplicateKey(
      timestamp: timestamp,
      amount: amount,
      source: source,
    );
    final duplicateFound = await _isDuplicate(duplicateKey);

    final validation = NotificationValidation.validate(
      parsing,
      timestamp: timestamp,
      source: source,
      amount: amount,
      duplicateFound: duplicateFound,
    );

    if (!validation.isValid) {
      return DebugTestResult(
        parsing: parsing,
        validation: validation,
        expense: null,
      );
    }

    final expense = Expense(
      id: 'debug_$timestamp',
      title: parsing.merchant?.isNotEmpty == true
          ? parsing.merchant!
          : (title.isNotEmpty ? title : 'Debug Transaction'),
      amount: amount,
      date: DateTime.fromMillisecondsSinceEpoch(timestamp),
      category: 'Other',
      description: 'Test / Debug Entry',
      type: parsing.transactionType == 'credit'
          ? TransactionType.income
          : TransactionType.expense,
      paymentMethod: source,
    );

    await _storeDebugEntry(
      duplicateKey: duplicateKey,
      timestamp: timestamp,
      sourceType: sourceType,
      parsing: parsing,
      validation: validation,
    );

    _logDebugTest(
      sourceType: sourceType,
      timestamp: timestamp,
      confidence: parsing.confidence,
      valid: validation.isValid,
    );

    return DebugTestResult(
      parsing: parsing,
      validation: validation,
      expense: expense,
    );
  }

  Future<void> clearDebugEntries() async {
    if (!kDebugMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_entriesKey);
    await prefs.remove(_keysKey);
  }

  Future<List<Map<String, dynamic>>> getDebugEntries() async {
    if (!kDebugMode) return <Map<String, dynamic>>[];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_entriesKey) ?? <String>[];
    return raw.map((e) {
      try {
        return jsonDecode(e) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _storeDebugEntry({
    required String duplicateKey,
    required int timestamp,
    required String sourceType,
    required ParsingResult parsing,
    required ValidationResult validation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_entriesKey) ?? <String>[];
    final keys = prefs.getStringList(_keysKey) ?? <String>[];

    final entry = <String, dynamic>{
      'timestamp': timestamp,
      'sourceType': sourceType,
      'amount': parsing.amount,
      'transactionType': parsing.transactionType,
      'merchant': parsing.merchant,
      'confidence': parsing.confidence,
      'valid': validation.isValid,
      'reasons': validation.reasons,
    };

    entries.add(jsonEncode(entry));
    keys.add(duplicateKey);

    await prefs.setStringList(_entriesKey, entries);
    await prefs.setStringList(_keysKey, keys);
  }

  Future<bool> _isDuplicate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList(_keysKey) ?? <String>[];
    return keys.contains(key);
  }

  void _logDebugTest({
    required String sourceType,
    required int timestamp,
    required double confidence,
    required bool valid,
  }) {
    // Debug-only log, no raw message content is logged.
    debugPrint(
      'DebugTestNotification: source=$sourceType '
      'timestamp=$timestamp confidence=$confidence valid=$valid',
    );
  }
}
