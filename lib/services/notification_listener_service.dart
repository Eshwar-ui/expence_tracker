import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/notification_payload.dart';
import '../models/pending_transaction.dart';
import '../utils/notification_parsing.dart';
import '../utils/transaction_parser.dart';
import 'pending_transaction_service.dart';

class NotificationListenerService {
  static const int _maxRecentProcessedKeys = 100;
  static const Duration _recentProcessedTtl = Duration(minutes: 5);

  NotificationListenerService._();

  static const String _logTag = 'NotificationListenerService';

  static final NotificationListenerService _instance =
      NotificationListenerService._();

  factory NotificationListenerService() => _instance;

  static const MethodChannel _methodChannel = MethodChannel(
    'com.eshwar.expensetracker/notification_listener/methods',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.eshwar.expensetracker/notification_listener/events',
  );

  static const List<String> _allowedPackages = [
    'com.google.android.apps.nbu.paisa.user',
    'com.phonepe.app',
    'net.one97.paytm',
    'in.org.npci.upiapp',
    'com.amazon.mobile.android',
    'com.mobikwik_new',
    'com.freecharge.android',
    'com.airtel.money',
    'com.axis.mobile',
    'com.hdfcbank.hdfcpayzapp',
    'com.sbi.SBIFreedomPlus',
  ];

  final PendingTransactionService _pendingTransactionService =
      PendingTransactionService();

  StreamSubscription<dynamic>? _subscription;
  bool _isInitialized = false;
  final Map<String, DateTime> _recentProcessedKeys = <String, DateTime>{};

  Future<void> initialize() async {
    if (_isInitialized) return;
    // Flag synchronously so two concurrent callers can't both attach a
    // listener and double-process every incoming notification.
    _isInitialized = true;

    try {
      await _setAllowedPackages();
      await _drainPendingNotifications();

      await _subscription?.cancel();
      _subscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) async {
          final payload = NotificationPayload.fromMap(
            Map<dynamic, dynamic>.from(event as Map),
          );
          debugPrint('$_logTag: live event package=${payload.packageName}');
          await _handlePayload(payload);
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('$_logTag: stream error $error');
        },
      );
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
    debugPrint('$_logTag: disposed');
  }

  Future<bool> isListenerEnabled() async {
    final enabled = await _methodChannel.invokeMethod<dynamic>(
      'isListenerEnabled',
    );
    return enabled == true;
  }

  Future<void> openNotificationSettings() async {
    await _methodChannel.invokeMethod<void>('openNotificationSettings');
  }

  Future<void> _setAllowedPackages() async {
    await _methodChannel.invokeMethod<void>(
      'setAllowedPackages',
      _allowedPackages,
    );
    debugPrint(
      '$_logTag: configured ${_allowedPackages.length} allowed packages',
    );
  }

  Future<void> _drainPendingNotifications() async {
    final pending = await _methodChannel.invokeMethod<dynamic>(
      'getPendingNotifications',
    );

    if (pending is! List) return;

    debugPrint('$_logTag: draining ${pending.length} queued notifications');

    for (final item in pending) {
      if (item is! Map) continue;
      final payload = NotificationPayload.fromMap(item);
      debugPrint('$_logTag: queued event package=${payload.packageName}');
      await _handlePayload(payload);
    }
  }

  Future<void> _handlePayload(NotificationPayload payload) async {
    final title = payload.title.trim();
    final text = payload.text.trim();
    if (title.isEmpty && text.isEmpty) return;

    final parsingResult = NotificationParsing.parse(
      text,
      title: title,
    );
    final validation = NotificationValidation.validate(
      parsingResult,
      timestamp: payload.timestamp,
      source: payload.packageName,
    );

    if (!validation.isValid) return;

    final transactionType = parsingResult.transactionType;
    if (transactionType != 'debit' && transactionType != 'credit') return;

    final amount = parsingResult.amount;
    if (amount == null) return;

    final description = [title, text]
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    final merchant = parsingResult.merchant?.trim().isNotEmpty == true
        ? parsingResult.merchant!.trim()
        : TransactionParser.normalizeDescription(description);
    final duplicateKey = NotificationValidation.duplicateKey(
      timestamp: payload.timestamp,
      amount: amount,
      source: payload.packageName,
    );
    if (_wasRecentlyProcessed(duplicateKey)) return;

    final pendingTransaction = PendingTransaction(
      id: duplicateKey,
      amount: amount,
      merchantName: merchant,
      suggestedCategory: _resolveCategory(
        description,
        transactionType!,
      ),
      transactionType: transactionType,
      detectedFrom: payload.packageName,
      detectedAt: DateTime.fromMillisecondsSinceEpoch(payload.timestamp),
      rawNotificationText: text,
      description: title.isEmpty ? null : title,
    );

    await _pendingTransactionService.addPendingTransaction(pendingTransaction);
  }

  bool _wasRecentlyProcessed(String key) {
    final now = DateTime.now();
    _recentProcessedKeys.removeWhere(
      (_, timestamp) => now.difference(timestamp) > _recentProcessedTtl,
    );

    if (_recentProcessedKeys.containsKey(key)) {
      return true;
    }

    _recentProcessedKeys[key] = now;
    if (_recentProcessedKeys.length > _maxRecentProcessedKeys) {
      final oldestEntry = _recentProcessedKeys.entries.reduce(
        (a, b) => a.value.isBefore(b.value) ? a : b,
      );
      _recentProcessedKeys.remove(oldestEntry.key);
    }
    return false;
  }

  String _resolveCategory(String description, String transactionType) {
    final suggested = TransactionParser.suggestCategory(description);
    if (suggested != null && suggested.trim().isNotEmpty) {
      return suggested;
    }
    return transactionType == 'credit' ? 'Income' : 'Digital Payments';
  }
}
