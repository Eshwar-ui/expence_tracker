import 'expence.dart';

class AnalyticsData {
  final double totalIncome;
  final double totalExpenses;
  final double balance;
  final Map<String, double> categoryBreakdown;
  final Map<String, double> monthlyBreakdown;
  final Map<String, double> dailyBreakdown;
  final List<TransactionTrend> trends;
  final List<Expense> recentExpenses;
  final BudgetStatus budgetStatus;
  final List<SpendingInsight> insights;
  final double openingBalance;

  AnalyticsData({
    required this.totalIncome,
    required this.totalExpenses,
    required this.balance,
    required this.categoryBreakdown,
    required this.monthlyBreakdown,
    required this.dailyBreakdown,
    required this.trends,
    required this.recentExpenses,
    required this.budgetStatus,
    required this.insights,
    required this.openingBalance,
  });

  double get savingsPercentage {
    if (totalIncome == 0) return 0;
    return ((balance / totalIncome) * 100).clamp(0, 100);
  }

  double get expensePercentage {
    if (totalIncome == 0) return 0;
    return ((totalExpenses / totalIncome) * 100).clamp(0, 100);
  }

  Map<String, dynamic> toJson() {
    return {
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'balance': balance,
      'categoryBreakdown': categoryBreakdown,
      'monthlyBreakdown': monthlyBreakdown,
      'dailyBreakdown': dailyBreakdown,
      'trends': trends.map((t) => t.toJson()).toList(),
      'recentExpenses': recentExpenses.map((e) => e.toJson()).toList(),
      'budgetStatus': budgetStatus.toJson(),
      'insights': insights.map((i) => i.toJson()).toList(),
      'openingBalance': openingBalance,
    };
  }

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      totalIncome: (json['totalIncome'] as num).toDouble(),
      totalExpenses: (json['totalExpenses'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
      categoryBreakdown: Map<String, double>.from(json['categoryBreakdown']),
      monthlyBreakdown: Map<String, double>.from(json['monthlyBreakdown']),
      dailyBreakdown: Map<String, double>.from(json['dailyBreakdown']),
      trends: (json['trends'] as List)
          .map((t) => TransactionTrend.fromJson(t))
          .toList(),
      recentExpenses: (json['recentExpenses'] as List)
          .map((e) => Expense.fromJson(e))
          .toList(),
      budgetStatus: BudgetStatus.fromJson(json['budgetStatus']),
      insights:
          (json['insights'] as List?)
              ?.map((i) => SpendingInsight.fromJson(i))
              .toList() ??
          [],
      openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TransactionTrend {
  final DateTime date;
  final double income;
  final double expenses;
  final double balance;

  TransactionTrend({
    required this.date,
    required this.income,
    required this.expenses,
    required this.balance,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'income': income,
      'expenses': expenses,
      'balance': balance,
    };
  }

  factory TransactionTrend.fromJson(Map<String, dynamic> json) {
    return TransactionTrend(
      date: DateTime.parse(json['date']),
      income: (json['income'] as num).toDouble(),
      expenses: (json['expenses'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
    );
  }
}

class BudgetStatus {
  final Map<String, BudgetCategory> categories;
  final double totalBudget;
  final double totalSpent;
  final double remainingBudget;

  BudgetStatus({
    required this.categories,
    required this.totalBudget,
    required this.totalSpent,
    required this.remainingBudget,
  });

  double get budgetUtilizationPercentage {
    if (totalBudget == 0) return 0;
    return ((totalSpent / totalBudget) * 100).clamp(0, 100);
  }

  Map<String, dynamic> toJson() {
    return {
      'categories': categories.map((k, v) => MapEntry(k, v.toJson())),
      'totalBudget': totalBudget,
      'totalSpent': totalSpent,
      'remainingBudget': remainingBudget,
    };
  }

  factory BudgetStatus.fromJson(Map<String, dynamic> json) {
    return BudgetStatus(
      categories: (json['categories'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, BudgetCategory.fromJson(v)),
      ),
      totalBudget: (json['totalBudget'] as num).toDouble(),
      totalSpent: (json['totalSpent'] as num).toDouble(),
      remainingBudget: (json['remainingBudget'] as num).toDouble(),
    );
  }
}

class BudgetCategory {
  final String category;
  final double budget;
  final double spent;
  final double remaining;

  BudgetCategory({
    required this.category,
    required this.budget,
    required this.spent,
    required this.remaining,
  });

  double get utilizationPercentage {
    if (budget == 0) return 0;
    return ((spent / budget) * 100).clamp(0, 100);
  }

  bool get isOverBudget => spent > budget;

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'budget': budget,
      'spent': spent,
      'remaining': remaining,
    };
  }

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      category: json['category'],
      budget: (json['budget'] as num).toDouble(),
      spent: (json['spent'] as num).toDouble(),
      remaining: (json['remaining'] as num).toDouble(),
    );
  }
}

class SpendingInsight {
  final String title;
  final String description;
  final InsightType type;
  final double? amount;
  final String? category;

  SpendingInsight({
    required this.title,
    required this.description,
    required this.type,
    this.amount,
    this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'type': type.name,
      'amount': amount,
      'category': category,
    };
  }

  factory SpendingInsight.fromJson(Map<String, dynamic> json) {
    return SpendingInsight(
      title: json['title'],
      description: json['description'],
      type: InsightType.values.firstWhere((e) => e.name == json['type']),
      amount: (json['amount'] as num?)?.toDouble(),
      category: json['category'],
    );
  }
}

enum InsightType { warning, info, success, tip }

class MonthlyReport {
  final DateTime month;
  final double totalIncome;
  final double totalExpenses;
  final double savings;
  final Map<String, double> topCategories;
  final List<SpendingInsight> insights;
  final double averageDailySpending;
  final int transactionCount;

  MonthlyReport({
    required this.month,
    required this.totalIncome,
    required this.totalExpenses,
    required this.savings,
    required this.topCategories,
    required this.insights,
    required this.averageDailySpending,
    required this.transactionCount,
  });

  double get savingsRate {
    if (totalIncome == 0) return 0;
    return (savings / totalIncome) * 100;
  }
}
