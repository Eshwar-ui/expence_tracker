import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a [ReminderService.markLoggedToday] call.
///
/// [milestoneReached] is non-null only when *this* save crossed a milestone
/// (3, 7, 14, 30, 60, 100, 365 days). Use it to celebrate in the UI.
class StreakResult {
  final int currentStreak;
  final int longestStreak;
  final int? milestoneReached;

  const StreakResult({
    required this.currentStreak,
    required this.longestStreak,
    this.milestoneReached,
  });

  const StreakResult.empty()
      : currentStreak = 0,
        longestStreak = 0,
        milestoneReached = null;
}

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

  static const _prefStreakDate = 'streak_last_date';
  static const _prefStreakCurrent = 'streak_current';
  static const _prefStreakLongest = 'streak_longest';

  static const List<int> _milestones = [3, 7, 14, 30, 60, 100, 365];

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

  /// Call after a successful expense save. Updates the streak counters and
  /// writes today's date to the user doc so the Cloud Function skips
  /// tonight's reminder.
  ///
  /// Idempotent within a day: calling twice on the same day will not bump
  /// the streak again.
  Future<StreakResult> markLoggedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final yesterday = _yesterdayKey();
    final prevDate = prefs.getString(_prefStreakDate);

    int current = prefs.getInt(_prefStreakCurrent) ?? 0;
    int longest = prefs.getInt(_prefStreakLongest) ?? 0;

    int? milestone;
    if (prevDate == today) {
      // Already counted today — no change.
    } else {
      if (prevDate == yesterday) {
        current += 1;
      } else {
        current = 1;
      }
      if (current > longest) longest = current;
      if (_milestones.contains(current)) milestone = current;
    }

    await prefs.setString(_prefStreakDate, today);
    await prefs.setInt(_prefStreakCurrent, current);
    await prefs.setInt(_prefStreakLongest, longest);

    final user = _auth.currentUser;
    if (user != null) {
      unawaited(
        _firestore.collection('users').doc(user.uid).set({
          'reminderLastLoggedDate': today,
          'currentStreak': current,
          'longestStreak': longest,
        }, SetOptions(merge: true)).catchError((e) {
          debugPrint('markLoggedToday sync failed: $e');
        }),
      );
    }

    return StreakResult(
      currentStreak: current,
      longestStreak: longest,
      milestoneReached: milestone,
    );
  }

  /// Reads the current streak from local cache. Returns 0 if the streak is
  /// broken (last logged date was more than 1 day ago).
  Future<StreakResult> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_prefStreakDate);
    final longest = prefs.getInt(_prefStreakLongest) ?? 0;
    var current = prefs.getInt(_prefStreakCurrent) ?? 0;

    if (lastDate == null ||
        (lastDate != _todayKey() && lastDate != _yesterdayKey())) {
      current = 0;
    }

    return StreakResult(currentStreak: current, longestStreak: longest);
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

  String _todayKey() => _dateKey(DateTime.now());

  String _yesterdayKey() =>
      _dateKey(DateTime.now().subtract(const Duration(days: 1)));

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
