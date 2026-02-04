import '../models/expence.dart';
import '../models/analytics.dart';
import 'firestore_service.dart';
import 'budget_service.dart';

class AnalyticsService {
  final FirestoreService _firestoreService = FirestoreService();

  // Get comprehensive analytics data
  Future<AnalyticsData> getAnalyticsData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final start = startDate ?? DateTime(now.year, now.month, 1);
      final end = endDate ?? now;

      // Fetch all expenses once
      final allExpenses = await _firestoreService.getExpenses();

      // Filter expenses in the date range (inclusive of both start and end dates)
      final expenses = allExpenses.where((e) {
        return !e.date.isBefore(start) && !e.date.isAfter(end);
      }).toList();

      // Calculate opening balance (all transactions before start date)
      final openingBalance = allExpenses
          .where((e) => e.date.isBefore(start))
          .fold<double>(0.0, (sum, e) {
            if (e.type == TransactionType.income) return sum + e.amount;
            return sum - e.amount;
          });

      // Calculate totals for the range
      final totalIncome = expenses
          .where((e) => e.type == TransactionType.income)
          .fold<double>(0.0, (sum, e) => sum + e.amount);

      final totalExpenses = expenses
          .where((e) => e.type == TransactionType.expense)
          .fold<double>(0.0, (sum, e) => sum + e.amount);

      final balance = openingBalance + totalIncome - totalExpenses;

      // Category breakdown
      final categoryBreakdown = <String, double>{};
      for (final expense in expenses) {
        if (expense.type == TransactionType.expense) {
          categoryBreakdown[expense.category] =
              (categoryBreakdown[expense.category] ?? 0.0) + expense.amount;
        }
      }

      // Monthly breakdown
      final monthlyBreakdown = <String, double>{};
      for (final expense in expenses) {
        final monthKey =
            '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';
        monthlyBreakdown[monthKey] =
            (monthlyBreakdown[monthKey] ?? 0.0) + expense.amount;
      }

      // Daily breakdown (last 30 days)
      final dailyBreakdown = <String, double>{};
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      for (final expense in allExpenses) {
        if (expense.date.isAfter(thirtyDaysAgo) &&
            expense.type == TransactionType.expense) {
          final dayKey =
              '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}-${expense.date.day.toString().padLeft(2, '0')}';
          dailyBreakdown[dayKey] =
              (dailyBreakdown[dayKey] ?? 0.0) + expense.amount;
        }
      }

      // Generate trends
      final trends = _generateTrends(allExpenses);

      // Budget status
      final budgetStatus = await _getBudgetStatus(expenses);

      // Insights
      final insights = _generateInsights(expenses, totalIncome, totalExpenses);

      return AnalyticsData(
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        balance: balance,
        categoryBreakdown: categoryBreakdown,
        monthlyBreakdown: monthlyBreakdown,
        dailyBreakdown: dailyBreakdown,
        trends: trends,
        recentExpenses: expenses,
        budgetStatus: budgetStatus,
        insights: insights,
        openingBalance: openingBalance,
      );
    } catch (e) {
      throw Exception('Failed to get analytics data: $e');
    }
  }

  // Get expenses in date range
  Future<List<Expense>> _getExpensesInRange(
    DateTime start,
    DateTime end,
  ) async {
    final all = await _firestoreService.getExpenses();
    return all.where((e) {
      return !e.date.isBefore(start) && !e.date.isAfter(end);
    }).toList();
  }

  // Generate spending trends for last 7 days
  List<TransactionTrend> _generateTrends(List<Expense> allExpenses) {
    final trends = <TransactionTrend>[];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayExpenses = allExpenses
          .where((e) => !e.date.isBefore(dayStart) && e.date.isBefore(dayEnd))
          .toList();

      final dayIncome = dayExpenses
          .where((e) => e.type == TransactionType.income)
          .fold<double>(0.0, (sum, e) => sum + e.amount);

      final dayExpensesAmount = dayExpenses
          .where((e) => e.type == TransactionType.expense)
          .fold<double>(0.0, (sum, e) => sum + e.amount);

      trends.add(
        TransactionTrend(
          date: dayStart,
          income: dayIncome,
          expenses: dayExpensesAmount,
          balance: dayIncome - dayExpensesAmount,
        ),
      );
    }

    return trends;
  }

  // Get budget status
  Future<BudgetStatus> _getBudgetStatus(List<Expense> expenses) async {
    try {
      final budgetService = BudgetService();
      final userBudgets = await budgetService.getBudgets();

      final categories = <String, BudgetCategory>{};
      double totalBudget = 0;
      double totalSpent = 0;

      if (userBudgets.isEmpty) {
        return BudgetStatus(
          categories: {},
          totalBudget: 0,
          totalSpent: 0,
          remainingBudget: 0,
        );
      }

      for (final budget in userBudgets) {
        final spent = expenses
            .where(
              (e) =>
                  e.category.toLowerCase() == budget.category.toLowerCase() &&
                  e.type == TransactionType.expense,
            )
            .fold<double>(0.0, (sum, e) => sum + e.amount);

        categories[budget.category] = BudgetCategory(
          category: budget.category,
          budget: budget.limit,
          spent: spent,
          remaining: budget.limit - spent,
        );

        totalBudget += budget.limit;
        totalSpent += spent;
      }

      return BudgetStatus(
        categories: categories,
        totalBudget: totalBudget,
        totalSpent: totalSpent,
        remainingBudget: totalBudget - totalSpent,
      );
    } catch (e) {
      return BudgetStatus(
        categories: {},
        totalBudget: 0,
        totalSpent: 0,
        remainingBudget: 0,
      );
    }
  }

  // Get monthly report
  Future<MonthlyReport> getMonthlyReport(DateTime month) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final expenses = await _getExpensesInRange(startOfMonth, endOfMonth);

      final totalIncome = expenses
          .where((e) => e.type == TransactionType.income)
          .fold<double>(0.0, (sum, e) => sum + e.amount);

      final totalExpenses = expenses
          .where((e) => e.type == TransactionType.expense)
          .fold<double>(0.0, (sum, e) => sum + e.amount);

      final savings = totalIncome - totalExpenses;

      // Top categories
      final categoryTotals = <String, double>{};
      for (final expense in expenses) {
        if (expense.type == TransactionType.expense) {
          categoryTotals[expense.category] =
              (categoryTotals[expense.category] ?? 0.0) + expense.amount;
        }
      }

      final sortedCategories = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topCategories = Map.fromEntries(
        sortedCategories.take(5).map((e) => MapEntry(e.key, e.value)),
      );

      // Generate insights
      final insights = _generateInsights(expenses, totalIncome, totalExpenses);

      // Calculate average daily spending
      final daysInMonth = endOfMonth.day;
      final averageDailySpending = totalExpenses / daysInMonth;

      return MonthlyReport(
        month: month,
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        savings: savings,
        topCategories: topCategories,
        insights: insights,
        averageDailySpending: averageDailySpending,
        transactionCount: expenses.length,
      );
    } catch (e) {
      throw Exception('Failed to get monthly report: $e');
    }
  }

  // Generate spending insights
  List<SpendingInsight> _generateInsights(
    List<Expense> expenses,
    double totalIncome,
    double totalExpenses,
  ) {
    final insights = <SpendingInsight>[];

    // Savings rate insight
    final savingsRate = totalIncome > 0
        ? ((totalIncome - totalExpenses) / totalIncome) * 100
        : 0;
    if (savingsRate < 10) {
      insights.add(
        SpendingInsight(
          title: 'Low Savings Rate',
          description:
              'Your savings rate is ${savingsRate.toStringAsFixed(1)}%. Consider reducing expenses.',
          type: InsightType.warning,
        ),
      );
    } else if (savingsRate > 30) {
      insights.add(
        SpendingInsight(
          title: 'Excellent Savings!',
          description:
              'Great job! You\'re saving ${savingsRate.toStringAsFixed(1)}% of your income.',
          type: InsightType.success,
        ),
      );
    }

    // Category insights
    final categoryTotals = <String, double>{};
    for (final expense in expenses) {
      if (expense.type == TransactionType.expense) {
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0.0) + expense.amount;
      }
    }

    if (categoryTotals.isNotEmpty) {
      final topCategory = categoryTotals.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      insights.add(
        SpendingInsight(
          title: 'Top Spending Category',
          description:
              'You spent most on ${topCategory.key}: ₹${topCategory.value.toStringAsFixed(0)}',
          type: InsightType.info,
          amount: topCategory.value,
          category: topCategory.key,
        ),
      );
    }

    // Daily average insight
    final daysInMonth = DateTime.now().day;
    final averageDailySpending = daysInMonth > 0
        ? totalExpenses / daysInMonth
        : 0.0;
    insights.add(
      SpendingInsight(
        title: 'Daily Average',
        description:
            'You spend ₹${averageDailySpending.toStringAsFixed(0)} per day on average.',
        type: InsightType.tip,
        amount: averageDailySpending,
      ),
    );

    return insights;
  }

  // Get spending patterns
  Future<Map<String, dynamic>> getSpendingPatterns() async {
    try {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final thisMonth = DateTime(now.year, now.month, 1);

      final lastMonthExpenses = await _getExpensesInRange(
        lastMonth,
        DateTime(now.year, now.month, 0, 23, 59, 59),
      );

      final thisMonthExpenses = await _getExpensesInRange(thisMonth, now);

      final lastMonthTotal = lastMonthExpenses
          .where((e) => e.type == TransactionType.expense)
          .fold<double>(0.0, (sum, e) => sum + e.amount);

      final thisMonthTotal = thisMonthExpenses
          .where((e) => e.type == TransactionType.expense)
          .fold<double>(0.0, (sum, e) => sum + e.amount);

      final change = lastMonthTotal > 0
          ? ((thisMonthTotal - lastMonthTotal) / lastMonthTotal) * 100
          : 0;

      return {
        'lastMonth': lastMonthTotal,
        'thisMonth': thisMonthTotal,
        'change': change,
        'trend': change > 0
            ? 'increasing'
            : change < 0
            ? 'decreasing'
            : 'stable',
      };
    } catch (e) {
      throw Exception('Failed to get spending patterns: $e');
    }
  }
}
