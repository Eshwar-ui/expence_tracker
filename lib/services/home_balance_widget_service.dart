import 'package:expence_tracker/models/analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

const String _rupee = '\u20B9';

class HomeBalanceWidgetService {
  static const String _balanceTextKey = 'balance_text';
  static const String _incomeTextKey = 'income_text';
  static const String _expenseTextKey = 'expense_text';
  static const String _updatedAtTextKey = 'updated_at_text';

  static const String _androidProviderQualifiedName =
      'com.eshwar.expensetracker.BalanceHomeWidgetProvider';

  static final NumberFormat _moneyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: _rupee,
    decimalDigits: 0,
  );

  static Future<void> updateFromAnalytics(AnalyticsData data) async {
    try {
      final updatedAt = DateFormat('hh:mm a').format(DateTime.now());

      await Future.wait([
        HomeWidget.saveWidgetData<String>(
          _balanceTextKey,
          _moneyFormatter.format(data.balance),
        ),
        HomeWidget.saveWidgetData<String>(
          _incomeTextKey,
          _moneyFormatter.format(data.totalIncome),
        ),
        HomeWidget.saveWidgetData<String>(
          _expenseTextKey,
          _moneyFormatter.format(data.totalExpenses),
        ),
        HomeWidget.saveWidgetData<String>(
          _updatedAtTextKey,
          'Updated $updatedAt',
        ),
      ]);

      await HomeWidget.updateWidget(
        qualifiedAndroidName: _androidProviderQualifiedName,
      );
    } catch (error) {
      debugPrint('Failed to update home screen balance widget: $error');
    }
  }
}
