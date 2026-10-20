import 'package:expence_tracker/services/widget_quick_add_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('widget links map only to the supported expense actions', () {
    for (final action in WidgetExpenseAction.values) {
      expect(
          WidgetExpenseAction.fromUri(
              Uri.parse('expense-widget://${action.name}')),
          action);
    }
    for (final uri in [
      'https://add',
      'expense-widget://delete',
      'expense-widget://add?amount=100',
      'expense-widget://add/extra',
      'expense-widget://voice#anything'
    ]) {
      expect(WidgetExpenseAction.fromUri(Uri.parse(uri)), isNull);
    }
  });

  test('category shortcuts select expense categories without setting an amount',
      () {
    expect(WidgetExpenseAction.food.category, 'Food');
    expect(WidgetExpenseAction.travel.category, 'Transportation');
    expect(WidgetExpenseAction.shopping.category, 'Shopping');
    expect(WidgetExpenseAction.add.category, isNull);
    expect(WidgetExpenseAction.voice.category, isNull);
  });

  test('queued action is consumed once, so rebuilds cannot reopen it', () {
    final service = WidgetQuickAddService.instance;
    service.pending.value = WidgetExpenseAction.food;
    expect(service.take(), WidgetExpenseAction.food);
    expect(service.take(), isNull);
  });

  test('closed-app launch and subsequent widget taps use the same intake',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('home_widget');
    const updates = MethodChannel('home_widget/updates');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'initiallyLaunchedFromHomeWidget'
            ? 'expense-widget://food'
            : null);
    messenger.setMockMethodCallHandler(updates, (_) async => null);
    final service = WidgetQuickAddService.instance;
    addTearDown(() async {
      await service.dispose();
      service.take();
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(updates, null);
    });
    await service.initialize();
    expect(service.take(), WidgetExpenseAction.food);
    final handled = Future<void>(() {});
    // Inject the same event envelope Android emits for an already-running app.
    // ignore: deprecated_member_use
    await messenger.handlePlatformMessage(
        'home_widget/updates',
        const StandardMethodCodec()
            .encodeSuccessEnvelope('expense-widget://voice'),
        (_) {});
    await handled;
    expect(service.take(), WidgetExpenseAction.voice);
    expect(service.take(), isNull);
  });

  test('pinning uses each registered Android provider', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('home_widget');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'isRequestPinWidgetSupported' ? true : null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    expect(await WidgetQuickAddService.pin(shortcuts: false), isTrue);
    expect(await WidgetQuickAddService.pin(shortcuts: true), isTrue);
    final pins =
        calls.where((call) => call.method == 'requestPinWidget').toList();
    expect(pins[0].arguments['qualifiedAndroidName'],
        'com.eshwar.expensetracker.QuickExpenseWidgetProvider');
    expect(pins[1].arguments['qualifiedAndroidName'],
        'com.eshwar.expensetracker.ExpenseShortcutsWidgetProvider');
  });
}
