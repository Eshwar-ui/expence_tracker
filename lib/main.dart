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
import 'package:expence_tracker/screens/categories_screen.dart';
import 'package:expence_tracker/firebase_options.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:expence_tracker/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:expence_tracker/screens/splash_screen.dart';
import 'package:expence_tracker/widgets/responsive_layout.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:expence_tracker/services/app_icon_switcher.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Load environment variables
    await dotenv.load(fileName: ".env");

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize notification service
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await NotificationService().initialize();

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial check on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppIconTheme();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      home: const VideoSplashScreen(),
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
