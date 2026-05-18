import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/pending_transaction.dart';

/// Action ids surfaced when a user taps a button (or the body) of a pending
/// transaction notification.
class PendingNotificationAction {
  static const String confirm = 'confirm';
  static const String review = 'review';
  static const String body = 'body';

  final String pendingId;
  final String actionId;

  const PendingNotificationAction({
    required this.pendingId,
    required this.actionId,
  });
}

/// Shows a heads-up notification when a new pending transaction is detected
/// from a UPI app, with two action buttons:
///   - "Confirm" — caller saves it as an Expense in one tap
///   - "Review"  — caller opens the pending-transactions screen
///
/// Action taps are broadcast on [actions] so any subscriber (typically
/// `main.dart`) can dispatch the right behavior.
///
/// Action handling is foreground / app-launch only: a tap on a killed-app
/// notification launches the app, and we replay the response via
/// `getNotificationAppLaunchDetails()` once the UI is up. We deliberately
/// skip true background isolate processing — it requires re-initing
/// Firebase in the second isolate and is brittle on Android cold-starts.
class PendingNotificationService {
  PendingNotificationService._();
  static final PendingNotificationService instance =
      PendingNotificationService._();

  static const _channelId = 'pending_transaction_alert';
  static const _channelName = 'Detected Transactions';
  static const _channelDesc =
      'Suggested transactions from your UPI apps that need a quick confirm.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final _actionController =
      StreamController<PendingNotificationAction>.broadcast();
  Stream<PendingNotificationAction> get actions => _actionController.stream;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onResponse,
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // If the app was launched by tapping a notification (action or body),
    // replay the response so subscribers process it after the first frame.
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        final resp = launch!.notificationResponse;
        if (resp != null) {
          // Microtask so the action fires after main.dart subscribes.
          scheduleMicrotask(() => _onResponse(resp));
        }
      }
    } catch (e) {
      debugPrint('PendingNotificationService: launch-replay failed: $e');
    }
  }

  Future<void> showPending(PendingTransaction t) async {
    final notifId = _notifIdFor(t.id);
    final amountStr = t.amount == t.amount.truncateToDouble()
        ? t.amount.toStringAsFixed(0)
        : t.amount.toStringAsFixed(2);

    final title = '${t.isCredit ? 'Received' : 'Spent'} ₹$amountStr'
        ' · ${t.appName}';
    final bodyParts = <String>[
      if (t.merchantName.isNotEmpty) t.merchantName,
      if (t.suggestedCategory != null) t.suggestedCategory!,
    ];
    final body = bodyParts.isEmpty
        ? 'Tap Confirm to save it.'
        : bodyParts.join(' • ');

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.recommendation,
        icon: '@mipmap/ic_launcher',
        actions: [
          AndroidNotificationAction(
            PendingNotificationAction.confirm,
            'Confirm',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            PendingNotificationAction.review,
            'Review',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
    );

    await _plugin.show(notifId, title, body, details, payload: t.id);
  }

  Future<void> cancel(String pendingId) async {
    await _plugin.cancel(_notifIdFor(pendingId));
  }

  void _onResponse(NotificationResponse response) {
    final pendingId = response.payload;
    if (pendingId == null || pendingId.isEmpty) return;
    final actionId = response.actionId ?? PendingNotificationAction.body;
    _actionController.add(
      PendingNotificationAction(pendingId: pendingId, actionId: actionId),
    );
  }

  /// Notification ids are 32-bit ints, so we hash and mask off the sign bit.
  int _notifIdFor(String pendingId) => pendingId.hashCode & 0x7FFFFFFF;
}
