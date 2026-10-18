import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/widgets/expense_heatmap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Expense transaction(String id, DateTime date, double amount,
        [TransactionType type = TransactionType.expense]) =>
    Expense(
        id: id,
        title: id,
        amount: amount,
        date: date,
        category: 'Food',
        type: type);

void main() {
  test('calendar begins on Monday and crosses the year boundary', () {
    final start = ExpenseHeatmap.startDate(DateTime(2026, 1, 1));
    expect(start, DateTime(2025, 10, 6));
    expect(start.weekday, DateTime.monday);
  });

  test(
      'daily totals combine expenses and exclude income and out-of-range dates',
      () {
    final today = DateTime(2026, 10, 19);
    final totals = ExpenseHeatmap.dailyTotals([
      transaction('morning', DateTime(2026, 10, 19, 9), 100),
      transaction('evening', DateTime(2026, 10, 19, 22), 250),
      transaction('income', today, 5000, TransactionType.income),
      transaction('future', DateTime(2026, 10, 20), 999),
      transaction('old', DateTime(2025), 999),
      transaction('invalid', today, double.nan),
    ], today);
    expect(totals, {today: 350.0});
  });

  testWidgets('compact layout supports selecting days and updating totals',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ExpenseHeatmap(
              today: DateTime(2026, 10, 19),
              expenses: [transaction('coffee', DateTime(2026, 10, 18), 250)],
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('expense-day-2026-10-18')));
    await tester.pump();
    expect(find.textContaining('18 Oct · ₹250.00'), findsOneWidget);
    expect(find.byKey(const ValueKey('expense-day-2026-10-20')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
