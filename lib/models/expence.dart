import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { income, expense }

class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String description;
  final TransactionType type;
  final String? tags;
  final String? location;
  final String? paymentMethod;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.description = '',
    this.type = TransactionType.expense,
    this.tags,
    this.location,
    this.paymentMethod,
  });

  // Convert Expense to Map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'category': category,
      'description': description,
      'type': type.name,
      'tags': tags,
      'location': location,
      'paymentMethod': paymentMethod,
    };
  }

  // Create Expense from Map (JSON deserialization)
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: _parseDate(json['date']),
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] != null
          ? TransactionType.values.firstWhere(
              (e) => e.name == json['type'],
              orElse: () => TransactionType.expense,
            )
          : TransactionType.expense,
      tags: json['tags'],
      location: json['location'],
      paymentMethod: json['paymentMethod'],
    );
  }

  // Parse date from either a Firestore Timestamp or an ISO 8601 String
  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  // Copy with method for updating expenses
  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    String? description,
    TransactionType? type,
    String? tags,
    String? location,
    String? paymentMethod,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      location: location ?? this.location,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}
