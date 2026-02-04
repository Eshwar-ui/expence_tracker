import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final LocalAuthentication auth = LocalAuthentication();
  static const String _lockEnabledKey = 'device_lock_enabled';

  // Check if any biometric or device lock is available
  Future<bool> canAuthenticate() async {
    final bool canCheckBiometrics = await auth.canCheckBiometrics;
    final bool isSupported =
        canCheckBiometrics || await auth.isDeviceSupported();
    return isSupported;
  }

  // Get current lock state
  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lockEnabledKey) ?? false;
  }

  // Set lock state
  Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockEnabledKey, enabled);
  }

  // Authenticate user
  Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to access your Expense Tracker',
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
      return didAuthenticate;
    } catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }
}
