import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/pending_transaction.dart';
import '../services/pending_transaction_service.dart';
import '../services/notification_listener_channel.dart';
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

  bool _isListening = false;
  final NotificationListenerChannel _nativeChannel =
      NotificationListenerChannel();

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

    // 2. Initialize local notifications
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
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // 3. Initialize Timezone for scheduled reminders
    tz.initializeTimeZones();

    // 4. Handle messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 5. Initialize Native Notification Listener & Allowlist
    await _nativeChannel.setAllowedPackages(_paymentApps);
    await _initNotificationListener();

    // Register token if user is already logged in
    if (_auth.currentUser != null) {
      await registerToken();
    }
  }

  Future<void> _initNotificationListener() async {
    try {
      final bool hasPermission = await _nativeChannel.isListenerEnabled();
      if (!hasPermission) {
        debugPrint('Native Notification Listener Permission not granted.');
        return;
      }

      _nativeChannel.stream.listen((payload) {
        debugPrint('Incoming native payload: ${payload.packageName}');
        final evt = PendingTransaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: TransactionParser.extractAmount(payload.text) ?? 0.0,
          merchantName: TransactionParser.normalizeDescription(payload.text),
          detectedFrom: payload.packageName,
          detectedAt: DateTime.now(),
          rawNotificationText: payload.text,
          description: payload.title,
        );

        if (evt.amount > 0) {
          _processTransactionEvent(evt);
        }
      });

      _isListening = true;
      debugPrint('Notification Listener stream connected');
    } catch (e) {
      debugPrint('Error initializing notification listener: $e');
    }
  }

  Future<void> _processTransactionEvent(PendingTransaction transaction) async {
    if (_auth.currentUser == null) return;

    try {
      await PendingTransactionService().addPendingTransaction(transaction);

      // Broadcast for real-time UI popup
      _detectedTransactionController.add(transaction);

      // Notify user via system tray
      _localNotifications.show(
        DateTime.now().millisecond,
        'Transaction Detected',
        '₹${transaction.amount} from ${transaction.merchantName} - Tap to review',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'pending_transaction',
            'Pending Transactions',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to process transaction event: $e');
    }
  }

  // Removed processPaymentNotification and replaced with processTransactionEvent flow

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
    final amount = TransactionParser.extractAmount(body) ?? 0.0;
    final merchant = TransactionParser.normalizeDescription(body);

    final transaction = PendingTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      merchantName: merchant,
      detectedFrom: packageName,
      detectedAt: DateTime.now(),
      rawNotificationText: body,
      description: 'Test Simulation',
    );

    await _processTransactionEvent(transaction);
  }

  // Daily Reminder Logic
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    const androidDetails = AndroidNotificationDetails(
      'daily_reminders',
      'Daily Reminders',
      channelDescription: 'Log your expenses daily',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    // Schedule for everyday at the specific time
    await _localNotifications.zonedSchedule(
      0,
      'Daily Expense Check',
      'Don\'t forget to log your expenses for today!',
      _nextInstanceOfTime(hour, minute),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint('Daily reminder scheduled for $hour:$minute');
  }

  Future<void> testDailyReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'daily_reminders',
      'Daily Reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _localNotifications.show(
      999,
      'Test Reminder',
      'This is what your daily expense reminder looks like!',
      const NotificationDetails(android: androidDetails),
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // Request permission for notification listener (User action required)
  Future<void> requestNotificationListenerPermission() async {
    try {
      await _nativeChannel.openNotificationSettings();
    } catch (e) {
      debugPrint('Error opening settings: $e');
    }
  }
}
