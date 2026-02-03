import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurringFrequency { daily, weekly, monthly, yearly }

class RecurringTransaction {
  final String id;
  final String userId;
  final String title;
  final String description;
  final double amount;
  final String category;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastExecuted;

  RecurringTransaction({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.lastExecuted,
  });

  // Calculate next execution date
  DateTime? getNextExecutionDate() {
    if (!isActive) return null;

    DateTime nextDate = lastExecuted ?? startDate;

    switch (frequency) {
      case RecurringFrequency.daily:
        nextDate = nextDate.add(const Duration(days: 1));
        break;
      case RecurringFrequency.weekly:
        nextDate = nextDate.add(const Duration(days: 7));
        break;
      case RecurringFrequency.monthly:
        nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
        break;
      case RecurringFrequency.yearly:
        nextDate = DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
        break;
    }

    // Check if we've passed the end date
    if (endDate != null && nextDate.isAfter(endDate!)) {
      return null;
    }

    return nextDate;
  }

  // Check if transaction should be executed today
  bool shouldExecuteToday() {
    if (!isActive) return false;

    final nextDate = getNextExecutionDate();
    if (nextDate == null) return false;

    final today = DateTime.now();
    return nextDate.year == today.year &&
        nextDate.month == today.month &&
        nextDate.day == today.day;
  }

  // Get frequency display text
  String get frequencyText {
    switch (frequency) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category,
      'frequency': frequency.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastExecuted': lastExecuted != null
          ? Timestamp.fromDate(lastExecuted!)
          : null,
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      frequency: RecurringFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => RecurringFrequency.monthly,
      ),
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: map['endDate'] != null
          ? (map['endDate'] as Timestamp).toDate()
          : null,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      lastExecuted: map['lastExecuted'] != null
          ? (map['lastExecuted'] as Timestamp).toDate()
          : null,
    );
  }

  RecurringTransaction copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    double? amount,
    String? category,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastExecuted,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastExecuted: lastExecuted ?? this.lastExecuted,
    );
  }
}
