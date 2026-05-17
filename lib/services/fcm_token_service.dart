import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FcmTokenService {
  static const String _cachedTokenKey = 'cached_fcm_token';
  static const String _cachedUidKey = 'cached_fcm_uid';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  FcmTokenService._();

  static const String _logTag = 'FcmTokenService';
  static final FcmTokenService _instance = FcmTokenService._();

  factory FcmTokenService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    // Set the flag *synchronously* before any awaits so concurrent callers
    // can't both pass the guard and create duplicate listeners.
    _initialized = true;

    final user = _auth.currentUser;
    if (user == null) {
      _initialized = false;
      return;
    }

    try {
      await _requestPermission();
      await _syncCurrentToken();

      // Cancel any prior subscription before assigning a new one so we never
      // leak a listener even if initialize() races with itself.
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
        (token) async {
          await _saveToken(token);
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('$_logTag: token refresh listener error $error');
        },
      );
    } catch (e) {
      // Roll the flag back so a retry can succeed.
      _initialized = false;
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _initialized = false;
    debugPrint('$_logTag: disposed');
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      provisional: false,
      sound: true,
    );
    debugPrint(
      '$_logTag: notification permission status=${settings.authorizationStatus.name}',
    );
  }

  Future<void> _syncCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('$_logTag: getToken returned no token');
        return;
      }
      await _saveToken(token);
    } catch (e) {
      debugPrint('$_logTag: failed to fetch token $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final (cachedUid, cachedToken) = await _readCachedTokenPair();
    if (cachedUid == user.uid && cachedToken == token) {
      return;
    }

    final doc = _firestore.collection('users').doc(user.uid);
    await doc.set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      'lastKnownPlatform': defaultTargetPlatform.name,
    }, SetOptions(merge: true));

    try {
      await _secureStorage.write(key: _cachedUidKey, value: user.uid);
      await _secureStorage.write(key: _cachedTokenKey, value: token);
    } catch (_) {
      // Fallback only — secure storage is the preferred backend.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedUidKey, user.uid);
      await prefs.setString(_cachedTokenKey, token);
    }
  }

  /// Read cached (uid, token), migrating any legacy SharedPreferences values
  /// into secure storage on first read.
  Future<(String?, String?)> _readCachedTokenPair() async {
    try {
      final secureUid = await _secureStorage.read(key: _cachedUidKey);
      final secureToken = await _secureStorage.read(key: _cachedTokenKey);
      if (secureUid != null || secureToken != null) {
        return (secureUid, secureToken);
      }
    } catch (_) {
      // fall through to SharedPreferences fallback
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyUid = prefs.getString(_cachedUidKey);
    final legacyToken = prefs.getString(_cachedTokenKey);
    if (legacyUid != null || legacyToken != null) {
      try {
        if (legacyUid != null) {
          await _secureStorage.write(key: _cachedUidKey, value: legacyUid);
        }
        if (legacyToken != null) {
          await _secureStorage.write(key: _cachedTokenKey, value: legacyToken);
        }
        await prefs.remove(_cachedUidKey);
        await prefs.remove(_cachedTokenKey);
      } catch (_) {
        // If migration fails, leave the legacy values in place.
      }
    }
    return (legacyUid, legacyToken);
  }
}
