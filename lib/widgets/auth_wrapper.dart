import 'dart:async';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/fcm_token_service.dart';
import '../services/notification_listener_service.dart';
import '../services/security_service.dart';
import '../screens/auth_screen.dart';
import '../screens/lock_screen.dart';
import '../screens/main_scaffold.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final FcmTokenService _fcmTokenService = FcmTokenService();
  final NotificationListenerService _notificationListenerService =
      NotificationListenerService();
  final SecurityService _securityService = SecurityService();
  bool _isDeviceUnlocked = false;
  bool _notificationServiceStarted = false;
  bool _fcmTokenServiceStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _securityService.notifyBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      // If lock is enabled and the grace period elapsed, drop the unlock flag
      // so the next build shows LockScreen.
      if (_isDeviceUnlocked && _securityService.shouldRequireAuthOnResume()) {
        _securityService.lock();
        if (mounted) {
          setState(() {
            _isDeviceUnlocked = false;
          });
        }
      }
    }
  }

  Future<void> _startNotificationListener() async {
    if (_notificationServiceStarted) return;
    _notificationServiceStarted = true;
    try {
      await _notificationListenerService.initialize();
    } catch (_) {
      // Keep auth flow resilient even when notification capture is unavailable.
      _notificationServiceStarted = false;
    }
  }

  Future<void> _startFcmTokenSync() async {
    if (_fcmTokenServiceStarted) return;
    _fcmTokenServiceStarted = true;
    try {
      await _fcmTokenService.initialize();
    } catch (_) {
      _fcmTokenServiceStarted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          unawaited(_startNotificationListener());
          unawaited(_startFcmTokenSync());
          // User is authenticated, now check for device lock
          return FutureBuilder<bool>(
            future: _securityService.isLockEnabled(),
            builder: (context, lockSnapshot) {
              if (lockSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final bool isLockEnabled = lockSnapshot.data ?? false;

              if (isLockEnabled && !_isDeviceUnlocked) {
                return LockScreen(
                  onAuthenticated: () {
                    setState(() {
                      _isDeviceUnlocked = true;
                    });
                  },
                );
              }

              return const MainScaffold();
            },
          );
        } else {
          // Reset unlock state when user signs out
          _isDeviceUnlocked = false;
          _securityService.lock();
          unawaited(_fcmTokenService.dispose());
          _fcmTokenServiceStarted = false;
          unawaited(_notificationListenerService.dispose());
          _notificationServiceStarted = false;
          return const AuthScreen();
        }
      },
    );
  }
}
