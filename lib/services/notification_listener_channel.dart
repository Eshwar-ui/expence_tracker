import 'dart:async';

import 'package:flutter/services.dart';
import 'package:expence_tracker/models/notification_payload.dart';

class NotificationListenerChannel {
  static final NotificationListenerChannel _instance =
      NotificationListenerChannel._internal();
  factory NotificationListenerChannel() => _instance;
  NotificationListenerChannel._internal();

  static const MethodChannel _methodChannel =
      MethodChannel('com.eshwar.expensetracker/notification_listener/methods');
  static const EventChannel _eventChannel =
      EventChannel('com.eshwar.expensetracker/notification_listener/events');

  Stream<NotificationPayload>? _stream;

  Stream<NotificationPayload> get stream {
    _stream ??= _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return NotificationPayload.fromMap(event);
      }
      return const NotificationPayload(
        packageName: '',
        title: '',
        text: '',
        timestamp: 0,
      );
    }).where((payload) => payload.packageName.isNotEmpty);
    return _stream!;
  }

  Future<bool> setAllowedPackages(List<String> packages) async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('setAllowedPackages', packages);
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<List<String>> getAllowedPackages() async {
    try {
      final result =
          await _methodChannel.invokeMethod<List<dynamic>>('getAllowedPackages');
      return result?.map((e) => e.toString()).toList() ?? <String>[];
    } on PlatformException {
      return <String>[];
    }
  }

  Future<NotificationPayload?> getLastNotification() async {
    try {
      final result = await _methodChannel
          .invokeMethod<Map<dynamic, dynamic>>('getLastNotification');
      if (result == null) {
        return null;
      }
      return NotificationPayload.fromMap(result);
    } on PlatformException {
      return null;
    }
  }

  Future<List<NotificationPayload>> getPendingNotifications() async {
    try {
      final result = await _methodChannel
          .invokeMethod<List<dynamic>>('getPendingNotifications');
      if (result == null) {
        return <NotificationPayload>[];
      }
      return result
          .whereType<Map>()
          .map(NotificationPayload.fromMap)
          .where((payload) => payload.packageName.isNotEmpty)
          .toList();
    } on PlatformException {
      return <NotificationPayload>[];
    }
  }

  Future<bool> clearPendingNotifications() async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('clearPendingNotifications');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isListenerEnabled() async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('isListenerEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> openNotificationSettings() async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('openNotificationSettings');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> getAppPackageName() async {
    try {
      return await _methodChannel.invokeMethod<String>('getAppPackageName');
    } on PlatformException {
      return null;
    }
  }
}
