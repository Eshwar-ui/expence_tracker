import 'package:expence_tracker/screens/home.dart';
import 'package:expence_tracker/screens/auth_screen.dart';
import 'package:expence_tracker/screens/profile_screen.dart';
import 'package:expence_tracker/screens/scan_screen.dart';
import 'package:expence_tracker/screens/main_scaffold.dart';
import 'package:expence_tracker/screens/transactions_screen.dart';
import 'package:expence_tracker/screens/reports_screen.dart';
import 'package:expence_tracker/screens/budget_planner_screen.dart';
import 'package:expence_tracker/screens/recurring_transactions_screen.dart';
import 'package:expence_tracker/screens/ai_predictions_screen.dart';
import 'package:expence_tracker/services/auth_service.dart';
import 'package:expence_tracker/services/security_service.dart';
import 'package:expence_tracker/screens/lock_screen.dart';
import 'package:expence_tracker/screens/categories_screen.dart';
import 'package:expence_tracker/firebase_options.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Pass all uncaught "asynchronous" errors to FlutterError.onError.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // TODO: Log to Sentry/Crashlytics in the future
      if (kReleaseMode) {
        // Handle release mode error logging
      }
    };

    // Pass all uncaught errors from the framework to PlatformDispatcher.instance.onError.
    PlatformDispatcher.instance.onError = (error, stack) {
      // TODO: Log to Sentry/Crashlytics in the future
      return true;
    };

    runApp(const MyApp());
  }, (error, stack) {
    // Catch errors outside of the Flutter framework
    debugPrint('Uncaught error: $error');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expense Tracker',
      theme: AppDesignSystem.lightTheme,
      darkTheme: AppDesignSystem.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/scan': (context) => const ScanScreen(),
        '/transactions': (context) => const TransactionsScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/budget': (context) => const BudgetPlannerScreen(),
        '/recurring': (context) => const RecurringTransactionsScreen(),
        '/ai-predictions': (context) => const AIPredictionsScreen(),
        '/categories': (context) => const CategoriesScreen(),
        '/main': (context) => const MainScaffold(),
      },
    );
  }
}

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
