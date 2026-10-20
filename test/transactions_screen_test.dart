import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/screens/transactions_screen.dart';
import 'package:expence_tracker/widgets/sky_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<Expense> transactions() => [
      Expense(
          id: 'salary',
          title: 'Monthly salary',
          amount: 50000,
          date: DateTime.now(),
          category: 'Salary',
          type: TransactionType.income),
      Expense(
          id: 'coffee',
          title: 'Coffee with friends',
          amount: 250,
          date: DateTime.now().subtract(const Duration(hours: 1)),
          category: 'Food',
          description: 'Cafe visit'),
      Expense(
          id: 'rent',
          title: 'Apartment rent',
          amount: 12000,
          date: DateTime.now().subtract(const Duration(days: 35)),
          category: 'Housing'),
    ];

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
        'compact $brightness layout preserves search, filters and details',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: TransactionsScreen(
            loadTransactions: () async => transactions(),
            loadCategories: () async => []),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SkyBackground), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField).first, 'coffee');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.textContaining('1 transactions'), findsOneWidget);
      expect(find.text('₹250'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.tap(find.byTooltip('Clear search'));
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter transactions'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Expense'));
      final min = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Min');
      await tester.ensureVisible(min);
      await tester.enterText(min, '500');
      tester.testTextInput.hide();
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 transactions'), findsOneWidget);
      expect(find.text('₹12000'), findsOneWidget);
      final rent = find.byKey(const ValueKey('transaction-rent'));
      await tester.ensureVisible(rent);
      await tester.pumpAndSettle();
      final amount =
          find.descendant(of: rent, matching: find.text('-₹12000.00'));
      expect(tester.getTopRight(amount).dx,
          closeTo(tester.getTopRight(rent).dx - 16, 0.5));
      await tester.tap(rent);
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('₹12000.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('load errors retain retry and an empty search can be cleared',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
        home: TransactionsScreen(
      loadTransactions: () async {
        if (attempts++ == 0) throw StateError('offline');
        return transactions();
      },
      loadCategories: () async => [],
    )));
    await tester.pumpAndSettle();
    expect(find.text('Transactions unavailable'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'does-not-exist');
    await tester.pumpAndSettle();
    expect(find.text('No matching transactions'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('No matching transactions'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
