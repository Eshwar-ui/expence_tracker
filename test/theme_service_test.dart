import 'package:expence_tracker/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uses device appearance until a choice is saved', () async {
    final service = ThemeService();
    addTearDown(service.dispose);
    await service.load();
    expect(service.mode, ThemeMode.system);
    expect(service.resolveBrightness(Brightness.dark), Brightness.dark);
    expect(service.resolveBrightness(Brightness.light), Brightness.light);
  });

  test('restores dark and light selections across service restarts', () async {
    final first = ThemeService();
    final reopened = ThemeService();
    final reopenedAgain = ThemeService();
    addTearDown(first.dispose);
    addTearDown(reopened.dispose);
    addTearDown(reopenedAgain.dispose);
    await first.load();
    await first.setDarkMode(true);
    await reopened.load();
    expect(reopened.mode, ThemeMode.dark);
    expect(reopened.resolveBrightness(Brightness.light), Brightness.dark);
    await reopened.setDarkMode(false);
    await reopenedAgain.load();
    expect(reopenedAgain.mode, ThemeMode.light);
    expect(reopenedAgain.resolveBrightness(Brightness.dark), Brightness.light);
  });

  testWidgets('updates the running app theme without resetting navigation',
      (tester) async {
    final service = ThemeService();
    addTearDown(service.dispose);
    await service.load();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ListenableBuilder(
      listenable: service,
      builder: (context, child) => MaterialApp(
        navigatorKey: navigator,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: service.mode,
        themeAnimationDuration: Duration.zero,
        home: const Scaffold(body: Text('Home')),
      ),
    ));
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        body: Text('Profile: ${Theme.of(context).brightness.name}'),
      ),
    ));
    await tester.pumpAndSettle();
    await service.setDarkMode(true);
    await tester.pumpAndSettle();
    expect(find.text('Profile: dark'), findsOneWidget);
    await service.setDarkMode(false);
    await tester.pumpAndSettle();
    expect(find.text('Profile: light'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
  });
}
