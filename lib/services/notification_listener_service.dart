import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_payload.dart';
import '../models/pending_transaction.dart';
import '../utils/notification_parsing.dart';
import '../utils/transaction_parser.dart';
import 'pending_notification_service.dart';
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
  Future<void> _processing = Future<void>.value();
  final Map<String, DateTime> _recentProcessedKeys = <String, DateTime>{};

  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_isInitialized) return;
    // Flag synchronously so two concurrent callers can't both attach a
    // listener and double-process every incoming notification.
    _isInitialized = true;

    try {
      await _setAllowedPackages();
      await _drainPendingNotifications();

      await _subscription?.cancel();
      _subscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          final payload = NotificationPayload.fromMap(
            Map<dynamic, dynamic>.from(event as Map),
          );
          debugPrint('$_logTag: live event package=${payload.packageName}');
          unawaited(_processPayload(payload));
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

  Future<bool> isAutoSaveEnabled() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return (await SharedPreferences.getInstance()).getBool('auto_save_$uid') ??
        false;
  }

  Future<void> setAutoSaveEnabled(bool enabled) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await (await SharedPreferences.getInstance())
        .setBool('auto_save_$uid', enabled);
  }

  Future<void> refresh() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await initialize();
    await _drainPendingNotifications();
  }

  // Serialize live and replayed events, including the save, to avoid races.
  Future<void> _processPayload(NotificationPayload payload) {
    _processing = _processing.then((_) async {
      if (FirebaseAuth.instance.currentUser == null) return;
      await _handlePayload(payload);
      await _methodChannel.invokeMethod<void>(
          'acknowledgeNotification', payload.toMap());
    }).catchError((Object error, StackTrace stack) {
      // No acknowledgement: retry the persisted payload on the next resume.
      debugPrint('$_logTag: processing failed; retained for retry: $error');
    });
    return _processing;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
    _recentProcessedKeys.clear();
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
      await _processPayload(payload);
    }
  }

  Future<void> _handlePayload(NotificationPayload payload) async {
    final title = TransactionParser.normalizeText(payload.title).trim();
    final text = TransactionParser.normalizeText(payload.text).trim();
    if (title.isEmpty && text.isEmpty) return;

    // Hard-reject OTPs, cart/promo reminders, balance-only updates before
    // parsing — they often contain currency amounts and fool the scorer.
    final rejection = RejectionRules.rejectionReason(
      text,
      title: title,
      sender: payload.packageName,
    );
    if (rejection != null) {
      debugPrint('$_logTag: rejected ($rejection) ${payload.packageName}');
      return;
    }

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

    final description =
        [title, text].where((part) => part.trim().isNotEmpty).join(' ').trim();
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

    try {
      final added = await _pendingTransactionService
          .addPendingTransaction(pendingTransaction);
      if (!added) return;
      if (parsingResult.confidence >= 0.9 && await isAutoSaveEnabled()) {
        await _pendingTransactionService.confirmPending(pendingTransaction.id);
        return;
      }
    } catch (_) {
      _recentProcessedKeys.remove(duplicateKey);
      rethrow;
    }

    // Surface a heads-up notification with Confirm/Review actions so the
    // user can save the detection in one tap without opening the app.
    try {
      await PendingNotificationService.instance.showPending(pendingTransaction);
    } catch (e) {
      debugPrint('$_logTag: showPending failed (non-fatal): $e');
    }
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
