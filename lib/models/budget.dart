import 'package:cloud_firestore/cloud_firestore.dart';

enum BudgetFrequency { monthly, weekly, yearly }

enum BudgetStatus { onTrack, nearLimit, exceeded, notSet }

class Budget {
  final String id;
  final String userId;
  final String category;
  final double limit;
  final double spent;
  final BudgetFrequency frequency;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Budget({
    required this.id,
    required this.userId,
    required this.category,
    required this.limit,
    required this.spent,
    required this.frequency,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  BudgetStatus get status {
    if (limit <= 0) return BudgetStatus.notSet;

    final percentage = (spent / limit) * 100;
    if (percentage >= 100) return BudgetStatus.exceeded;
    if (percentage >= 80) return BudgetStatus.nearLimit;
    return BudgetStatus.onTrack;
  }

  double get remaining => limit - spent;
  double get percentage => limit > 0 ? (spent / limit) * 100 : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'category': category,
      'limit': limit,
      'spent': spent,
      'frequency': frequency.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      category: map['category'] ?? '',
      limit: (map['limit'] ?? 0).toDouble(),
      spent: (map['spent'] ?? 0).toDouble(),
      frequency: BudgetFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => BudgetFrequency.monthly,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
    );
  }

  Budget copyWith({
    String? id,
    String? userId,
    String? category,
    double? limit,
    double? spent,
    BudgetFrequency? frequency,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      limit: limit ?? this.limit,
      spent: spent ?? this.spent,
      frequency: frequency ?? this.frequency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

class BudgetPlan {
  final String id;
  final String userId;
  final double monthlyIncome;
  final List<Budget> budgets;
  final DateTime createdAt;
  final DateTime updatedAt;

  BudgetPlan({
    required this.id,
    required this.userId,
    required this.monthlyIncome,
    required this.budgets,
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalBudgeted =>
      budgets.fold(0, (sum, budget) => sum + budget.limit);
  double get totalSpent => budgets.fold(0, (sum, budget) => sum + budget.spent);
  double get remainingIncome => monthlyIncome - totalSpent;
  double get savingsTarget => monthlyIncome - totalBudgeted;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'monthlyIncome': monthlyIncome,
      'budgets': budgets.map((b) => b.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory BudgetPlan.fromMap(Map<String, dynamic> map) {
    return BudgetPlan(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      monthlyIncome: (map['monthlyIncome'] ?? 0).toDouble(),
      budgets:
          (map['budgets'] as List<dynamic>?)
              ?.map((b) => Budget.fromMap(b as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}
