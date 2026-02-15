import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import '../models/pending_transaction.dart';
import '../services/pending_transaction_service.dart';
import '../utils/transaction_parser.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ReceivePort? _port;
  bool _isListening = false;

  // Stream for real-time notification detection UI
  final _detectedTransactionController =
      StreamController<PendingTransaction>.broadcast();
  Stream<PendingTransaction> get detectedTransactionStream =>
      _detectedTransactionController.stream;

  // List of payment app package names to listen to
  final List<String> _paymentApps = [
    'com.google.android.apps.nbu.paisa.user', // Google Pay
    'com.phonepe.app', // PhonePe
    'net.one97.paytm', // Paytm
    'in.org.npci.upiapp', // BHIM
    'com.sbi.upi', // BHIM SBI Pay
  ];

  Future<void> initialize() async {
    // 1. Request permissions (especially for iOS)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // 2. Initialize local notifications for foreground messages
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // 3. Handle messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 4. Initialize Notification Listener
    await _initNotificationListener();

    // Register token if user is already logged in
    if (_auth.currentUser != null) {
      await registerToken();
    }
  }

  Future<void> _initNotificationListener() async {
    try {
      final bool? hasPermission = await NotificationsListener.hasPermission;
      if (hasPermission != true) {
        debugPrint(
            'Notification Listener Permission not granted. Requesting...');
        // Note: You must open the settings screen manually in a real app flow
        // NotificationsListener.openPermissionSettings();
        return;
      }

      _port = ReceivePort();
      IsolateNameServer.removePortNameMapping('_notification_listener_');
      IsolateNameServer.registerPortWithName(
        _port!.sendPort,
        '_notification_listener_',
      );

      _port!.listen((message) => _onNotificationReceived(message));

      await NotificationsListener.initialize(
        callbackHandle: _backgroundNotificationHandler,
      );

      // Start the service
      await NotificationsListener.startService();

      _isListening = true;
      debugPrint('Notification Listener started successfully');
    } catch (e) {
      debugPrint('Error initializing notification listener: $e');
    }
  }

  // Static callback for background execution
  @pragma('vm:entry-point')
  static void _backgroundNotificationHandler(NotificationEvent evt) {
    print(
        'Background Notification: ${evt.packageName}: ${evt.title} - ${evt.text}');
    final SendPort? send =
        IsolateNameServer.lookupPortByName('_notification_listener_');
    if (send != null) {
      send.send(evt);
    }
  }

  void _onNotificationReceived(NotificationEvent evt) {
    if (_paymentApps.contains(evt.packageName)) {
      debugPrint('Payment Notification Detected from: ${evt.packageName}');
      _processPaymentNotification(evt);
    }
  }

  Future<void> _processPaymentNotification(NotificationEvent evt) async {
    final String? title = evt.title;
    final String? body = evt.text;

    if (body == null) return;

    final double? amount = TransactionParser.extractAmount(body);
    if (amount != null && amount > 0) {
      debugPrint('Detected Amount: $amount');

      if (_auth.currentUser != null) {
        // Extract merchant name and suggest category
        final merchantName = TransactionParser.normalizeDescription(body);
        final suggestedCategory = TransactionParser.suggestCategory(body);

        // Create pending transaction for manual approval
        final pendingTransaction = PendingTransaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: amount,
          merchantName: merchantName,
          suggestedCategory: suggestedCategory,
          detectedFrom: evt.packageName ?? 'unknown',
          detectedAt: DateTime.now(),
          rawNotificationText: body,
          description: title,
        );

        try {
          await PendingTransactionService()
              .addPendingTransaction(pendingTransaction);

          // Broadcast for real-time UI popup
          _detectedTransactionController.add(pendingTransaction);

          // Notify user to review via system tray
          _localNotifications.show(
              DateTime.now().millisecond,
              'Transaction Detected',
              '₹$amount from $merchantName - Tap to review',
              const NotificationDetails(
                  android: AndroidNotificationDetails(
                'pending_transaction',
                'Pending Transactions',
                importance: Importance.high,
                priority: Priority.high,
              )));
        } catch (e) {
          debugPrint('Failed to save pending transaction: $e');
        }
      }
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');

    if (message.notification != null) {
      debugPrint(
          'Message also contained a notification: ${message.notification?.title}');

      // Show local notification
      _showLocalNotification(message);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('A new onMessageOpenedApp event was published!');
    // Navigate to specific screen based on message data if needed
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'daily_reminders',
      'Daily Reminders',
      channelDescription: 'Notifications for daily expense tracking reminders',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
      payload: message.data.toString(),
    );
  }

  Future<void> registerToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null && _auth.currentUser != null) {
        String userId = _auth.currentUser!.uid;
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('fcm_tokens')
            .doc(token)
            .set({
          'token': token,
          'createdAt': FieldValue.serverTimestamp(),
          'platform': defaultTargetPlatform.toString(),
        });
        debugPrint('FCM Token registered for user $userId');
      }
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  Future<void> unregisterToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null && _auth.currentUser != null) {
        String userId = _auth.currentUser!.uid;
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('fcm_tokens')
            .doc(token)
            .delete();
        debugPrint('FCM Token unregistered for user $userId');
      }
    } catch (e) {
      debugPrint('Error unregistering FCM token: $e');
    }
  }

  // Method to manually trigger a test notification processing (for UI testing)
  Future<void> testTransaction(String packageName, String body) async {
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    // uniqueId is likely string in the package but let's try to satisfy the linter.
    // IF the linter said "String cant be assigned to int?", then uniqueId expects int.
    // However, uniqueId in NotificationEvent is often a String map key.
    // Let's rely on the fact that I can see the error.
    // If I pass an int here, and it was actually String, I will get another error.

    // Attempting to construct with minimal required fields or nulls for uncertain ones logic.
    // Use dynamic to bypass check if unsure, but safer to try strict first.

    final evt = NotificationEvent(
      packageName: packageName,
      title: 'Test Notification',
      text: body,
      createAt: DateTime.now(),
      // timestamp and uniqueId causing type confusion without IDE.
      // Assuming they are optional.
    );
    await _processPaymentNotification(evt);
  }

  // Request permission for notification listener (User action required)
  Future<void> requestNotificationListenerPermission() async {
    try {
      await NotificationsListener.openPermissionSettings();
    } catch (e) {
      debugPrint('Error opening settings: $e');
    }
  }
}
