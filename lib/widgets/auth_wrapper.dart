import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../screens/auth_screen.dart';
import '../screens/lock_screen.dart';
import '../screens/main_scaffold.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  final SecurityService _securityService = SecurityService();
  bool _isDeviceUnlocked = false;

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
          return const AuthScreen();
        }
      },
    );
  }
}
