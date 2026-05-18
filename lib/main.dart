import 'package:expence_tracker/screens/home.dart';
import 'package:expence_tracker/screens/auth_screen.dart';
import 'package:expence_tracker/screens/profile_screen.dart';
import 'package:expence_tracker/screens/main_scaffold.dart';
import 'package:expence_tracker/screens/transactions_screen.dart';
import 'package:expence_tracker/screens/reports_screen.dart';
import 'package:expence_tracker/screens/budget_planner_screen.dart';
import 'package:expence_tracker/screens/recurring_transactions_screen.dart';
import 'package:expence_tracker/screens/ai_predictions_screen.dart';
import 'package:expence_tracker/screens/categories_screen.dart';
import 'package:expence_tracker/screens/smart_inbox_screen.dart';
import 'package:expence_tracker/firebase_options.dart';
import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/services/pending_notification_service.dart';
import 'package:expence_tracker/services/pending_transaction_service.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:expence_tracker/screens/splash_screen.dart';
import 'package:expence_tracker/widgets/responsive_layout.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:expence_tracker/services/app_icon_switcher.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await dotenv.load(fileName: ".env");
    } catch (e, s) {
      debugPrint('dotenv.load failed (non-fatal): $e\n$s');
    }

    // Firebase init is the most common cold-start failure point on Android
    // (Google Play Services not ready yet). Retry once before giving up so
    // the app doesn't die on the first launcher tap.
    var firebaseReady = false;
    for (var attempt = 0; attempt < 2 && !firebaseReady; attempt++) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        firebaseReady = true;
      } catch (e, s) {
        debugPrint('Firebase init attempt ${attempt + 1} failed: $e\n$s');
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
    }

    if (firebaseReady) {
      try {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(!kDebugMode);
      } catch (e) {
        debugPrint('Crashlytics enable failed (non-fatal): $e');
      }

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: true,
        );
        return true;
      };
    }

    // Local notifications for one-tap confirm of detected transactions.
    // Must run before runApp so a launch-tap response can be replayed once
    // the navigator is up.
    try {
      await PendingNotificationService.instance.initialize();
    } catch (e) {
      debugPrint('PendingNotificationService init failed (non-fatal): $e');
    }

    runApp(const MyApp());
  }, (error, stack) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      // Crashlytics not ready — swallow so we don't recurse into the zone.
    }
    debugPrint('Uncaught error: $error');
  });
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<PendingNotificationAction>? _pendingActionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial check on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppIconTheme();
    });
    _pendingActionSub =
        PendingNotificationService.instance.actions.listen(_onPendingAction);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_pendingActionSub?.cancel());
    super.dispose();
  }

  Future<void> _onPendingAction(PendingNotificationAction action) async {
    final navState = rootNavigatorKey.currentState;
    if (navState == null) return;
    final ctx = navState.context;

    switch (action.actionId) {
      case PendingNotificationAction.confirm:
        try {
          final Expense? saved =
              await PendingTransactionService().confirmPending(action.pendingId);
          if (!ctx.mounted) return;
          if (saved == null) {
            showDesignSystemSnackBar(
              context: ctx,
              message: 'Already handled — nothing to confirm.',
              isError: true,
            );
            return;
          }
          showDesignSystemSnackBar(
            context: ctx,
            message:
                '✓ Saved ${saved.type == TransactionType.income ? 'income' : 'expense'}: ₹${saved.amount.toStringAsFixed(saved.amount == saved.amount.truncateToDouble() ? 0 : 2)}',
          );
        } catch (e) {
          debugPrint('Notification confirm failed: $e');
          if (!ctx.mounted) return;
          showDesignSystemSnackBar(
            context: ctx,
            message: "Couldn't save that transaction. Open the app to review.",
            isError: true,
          );
        }
        break;
      case PendingNotificationAction.review:
      case PendingNotificationAction.body:
        unawaited(navState.pushNamed('/scan'));
        break;
    }
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    _checkAppIconTheme();
  }

  void _checkAppIconTheme() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (brightness == Brightness.dark) {
      AppIconSwitcher.switchToDark();
    } else {
      AppIconSwitcher.switchToLight();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Expense Tracker',
      theme: AppDesignSystem.lightTheme,
      darkTheme: AppDesignSystem.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return ResponsiveLayout(
          useContainer: false, // Don't add extra shadow globally here
          child: child!,
        );
      },
      home: const SplashScreen(),
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/scan': (context) => const SmartInboxScreen(),
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
