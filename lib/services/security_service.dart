import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton that owns biometric / device auth and the encrypted lock flag.
///
/// The "lock enabled" flag is stored in `flutter_secure_storage` (Keystore on
/// Android, Keychain on iOS) instead of plain SharedPreferences so a user
/// can't flip it by editing app data. Old SharedPreferences values are
/// migrated transparently on first read.
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final LocalAuthentication auth = LocalAuthentication();

  static const String _lockEnabledKey = 'device_lock_enabled';
  // How long after backgrounding before we re-prompt for auth on resume.
  // 0 = always re-auth; tune up if it becomes annoying.
  static const Duration _resumeAuthGrace = Duration.zero;

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// In-memory unlock state. Reset when the app is backgrounded long enough
  /// to require re-auth (see [shouldRequireAuthOnResume]).
  bool _isUnlocked = false;
  DateTime? _lastBackgroundedAt;

  bool get isUnlocked => _isUnlocked;

  /// True if any biometric or device credential is available.
  Future<bool> canAuthenticate() async {
    try {
      final canCheckBiometrics = await auth.canCheckBiometrics;
      return canCheckBiometrics || await auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Read the lock-enabled flag, migrating from SharedPreferences if needed.
  Future<bool> isLockEnabled() async {
    try {
      final secureValue = await _secureStorage.read(key: _lockEnabledKey);
      if (secureValue != null) return secureValue == 'true';

      // Migration: pull the legacy SharedPreferences value once, then
      // promote it into secure storage and clear the old key.
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getBool(_lockEnabledKey);
      if (legacy != null) {
        await _secureStorage.write(
          key: _lockEnabledKey,
          value: legacy.toString(),
        );
        await prefs.remove(_lockEnabledKey);
        return legacy;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setLockEnabled(bool enabled) async {
    try {
      await _secureStorage.write(
        key: _lockEnabledKey,
        value: enabled.toString(),
      );
    } catch (_) {
      // If Keystore is unavailable for some reason, fall back so the
      // user-visible toggle still has *some* persistence.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_lockEnabledKey, enabled);
    }
    if (!enabled) _isUnlocked = true;
  }

  /// Prompts the OS biometric / device credential sheet.
  /// We intentionally do NOT pass `persistAcrossBackgrounding: true` so the
  /// sheet does not silently auto-succeed after the app returns from background.
  Future<bool> authenticate() async {
    try {
      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to access your Expense Tracker',
        biometricOnly: false,
      );
      if (didAuthenticate) {
        _isUnlocked = true;
        _lastBackgroundedAt = null;
      }
      return didAuthenticate;
    } catch (e) {
      debugPrint('SecurityService: authenticate() failed: $e');
      return false;
    }
  }

  /// Called when the app goes to background so we can lock it on resume.
  void notifyBackgrounded() {
    _lastBackgroundedAt = DateTime.now();
  }

  /// Returns true if the wrapper should show the lock screen on resume.
  /// Honors the configured grace period.
  bool shouldRequireAuthOnResume() {
    if (!_isUnlocked) return true;
    final ts = _lastBackgroundedAt;
    if (ts == null) return false;
    return DateTime.now().difference(ts) >= _resumeAuthGrace;
  }

  /// Force re-lock (e.g. on sign out).
  void lock() {
    _isUnlocked = false;
    _lastBackgroundedAt = null;
  }
}
