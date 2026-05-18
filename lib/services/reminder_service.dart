import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Daily expense-logging reminder.
///
/// The schedule lives on the server (Cloud Function `dailyReminder` in
/// functions/index.js, on a 1-minute cron). This class only writes the user's
/// preferences to their Firestore doc so the function can match them:
///
/// - reminderEnabled: bool
/// - preferredNotificationTime: "HH:MM" string in Asia/Kolkata
/// - reminderLastLoggedDate: "yyyy-MM-dd" — set by markLoggedToday() so the
///   function can skip users who already logged today.
class ReminderService {
  ReminderService._();
  static final ReminderService _instance = ReminderService._();
  factory ReminderService() => _instance;

  static const _prefEnabled = 'reminder_enabled';
  static const _prefHour = 'reminder_hour';
  static const _prefMinute = 'reminder_minute';

  static const int defaultHour = 20;
  static const int defaultMinute = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String fcmChannelId = 'daily_expense_reminder';

  Future<void> initialize() async {
    const channel = AndroidNotificationChannel(
      fcmChannelId,
      'Daily Expense Reminder',
      description: 'Reminders to log your daily expenses',
      importance: Importance.high,
    );
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabled) ?? false;
  }

  Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_prefHour) ?? defaultHour,
      minute: prefs.getInt(_prefMinute) ?? defaultMinute,
    );
  }

  /// Returns true if the reminder is now active. False if the user denied
  /// notification permission or isn't signed in.
  Future<bool> enable(TimeOfDay time) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final granted = await _ensurePermission();
    if (!granted) return false;

    final formattedTime = _formatHHmm(time);

    await _firestore.collection('users').doc(user.uid).set({
      'reminderEnabled': true,
      'preferredNotificationTime': formattedTime,
      'reminderUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, true);
    await prefs.setInt(_prefHour, time.hour);
    await prefs.setInt(_prefMinute, time.minute);
    return true;
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, false);

    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'reminderEnabled': false,
      'reminderUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Call after a successful expense save. Writes today's date to the user
  /// doc so the Cloud Function skips tonight's reminder.
  Future<void> markLoggedToday() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'reminderLastLoggedDate': _todayKey(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('markLoggedToday failed: $e');
    }
  }

  Future<bool> _ensurePermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final status = settings.authorizationStatus;
      return status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('FCM permission request failed: $e');
      return false;
    }
  }

  String _formatHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
