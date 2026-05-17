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
import 'package:expence_tracker/utils/app_design_system.dart';
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

    // Load environment variables
    await dotenv.load(fileName: ".env");

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);

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

    runApp(const MyApp());
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
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
