import 'package:expence_tracker/models/analytics.dart';
import 'package:expence_tracker/screens/reports_screen.dart';
import 'package:expence_tracker/widgets/liquid_glass_card.dart';
import 'package:expence_tracker/widgets/sky_background.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

AnalyticsData reportData({bool empty = false}) => AnalyticsData(
      totalIncome: empty ? 0 : 60000,
      totalExpenses: empty ? 0 : 7000,
      balance: empty ? 0 : 55000,
      openingBalance: empty ? 0 : 2000,
      categoryBreakdown: empty
          ? {}
          : {
              'Food & groceries': 2500,
              'Transport': 1500,
              'Shopping': 1000,
              'Subscriptions': 800,
              'Entertainment': 600,
              'Health': 400,
              'Other': 200,
            },
      monthlyBreakdown: {},
      dailyBreakdown: empty
          ? {}
          : {'2026-10-01': 1000, '2026-10-10': 2500, '2026-10-18': 3500},
      trends: [],
      recentExpenses: [],
      budgetStatus: BudgetStatus(
          categories: {},
          totalBudget: empty ? 0 : 10000,
          totalSpent: empty ? 0 : 7000,
          remainingBudget: empty ? 0 : 3000),
      insights: empty
          ? []
          : [
              SpendingInsight(
                  title: 'Spending check-in',
                  description: 'Your spending is within the monthly budget.',
                  type: InsightType.info)
            ],
    );

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('compact reports remain readable in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: ReportsScreen(loadAnalytics: (_, __) async => reportData()),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SkyBackground), findsOneWidget);
      expect(find.byType(LiquidGlassCard), findsWidgets);
      expect(find.text('Monthly balance'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final pie = tester.widget<PieChart>(find.byType(PieChart));
      expect(pie.data.sections.length, 7);
      expect(
          pie.data.sections
              .fold<double>(0, (sum, section) => sum + section.value),
          7000);
      for (var i = 0; i < 10; i++) {
        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('failed reports can be refreshed without losing the month picker',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
        MaterialApp(home: ReportsScreen(loadAnalytics: (_, __) async {
      if (attempts++ == 0) throw StateError('offline');
      return reportData(empty: true);
    })));
    await tester.pumpAndSettle();
    expect(find.text('Reports unavailable'), findsOneWidget);
    expect(
      find.widgetWithText(
          TextButton, DateFormat('MMMM yyyy').format(DateTime.now())),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Reports unavailable'), findsNothing);
    expect(find.text('Monthly balance'), findsOneWidget);
    expect(find.text('No expense activity in this month'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
