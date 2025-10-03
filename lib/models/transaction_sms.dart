class TransactionSMS {
  final String id;
  final String bankName;
  final String accountNumber;
  final String transactionType; // 'credit' or 'debit'
  final double amount;
  final DateTime date;
  final String description;
  final String balance;
  final String originalMessage;
  final String sender;
  final String referenceNumber;
  final bool
  isAddedToExpenses; // Track if this SMS transaction has been added to expenses

  TransactionSMS({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.transactionType,
    required this.amount,
    required this.date,
    required this.description,
    required this.balance,
    required this.originalMessage,
    required this.sender,
    this.referenceNumber = 'N/A',
    this.isAddedToExpenses = false,
  });

  // Convert to Expense model
  Map<String, dynamic> toExpenseData() {
    return {
      'title': description,
      'amount': amount,
      'date': date,
      'category': _getCategoryFromDescription(description),
      'description': 'Auto-detected from SMS: $bankName',
    };
  }

  String _getCategoryFromDescription(String description) {
    final desc = description.toLowerCase();

    if (desc.contains('food') ||
        desc.contains('restaurant') ||
        desc.contains('grocery')) {
      return 'Food';
    } else if (desc.contains('fuel') ||
        desc.contains('petrol') ||
        desc.contains('transport')) {
      return 'Transportation';
    } else if (desc.contains('movie') ||
        desc.contains('entertainment') ||
        desc.contains('netflix')) {
      return 'Entertainment';
    } else if (desc.contains('shopping') ||
        desc.contains('amazon') ||
        desc.contains('flipkart')) {
      return 'Shopping';
    } else if (desc.contains('bill') ||
        desc.contains('electricity') ||
        desc.contains('water')) {
      return 'Bills';
    } else if (desc.contains('medical') ||
        desc.contains('hospital') ||
        desc.contains('pharmacy')) {
      return 'Healthcare';
    } else if (desc.contains('education') ||
        desc.contains('school') ||
        desc.contains('book')) {
      return 'Education';
    } else {
      return 'Other';
    }
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'transactionType': transactionType,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'balance': balance,
      'originalMessage': originalMessage,
      'sender': sender,
      'referenceNumber': referenceNumber,
      'isAddedToExpenses': isAddedToExpenses,
    };
  }

  // Create from JSON
  factory TransactionSMS.fromJson(Map<String, dynamic> json) {
    return TransactionSMS(
      id: json['id'],
      bankName: json['bankName'],
      accountNumber: json['accountNumber'],
      transactionType: json['transactionType'],
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      description: json['description'],
      balance: json['balance'],
      originalMessage: json['originalMessage'],
      sender: json['sender'],
      referenceNumber: json['referenceNumber'] ?? 'N/A',
      isAddedToExpenses: json['isAddedToExpenses'] ?? false,
    );
  }

  // Copy with method for updating
  TransactionSMS copyWith({
    String? id,
    String? bankName,
    String? accountNumber,
    String? transactionType,
    double? amount,
    DateTime? date,
    String? description,
    String? balance,
    String? originalMessage,
    String? sender,
    String? referenceNumber,
    bool? isAddedToExpenses,
  }) {
    return TransactionSMS(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      balance: balance ?? this.balance,
      originalMessage: originalMessage ?? this.originalMessage,
      sender: sender ?? this.sender,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      isAddedToExpenses: isAddedToExpenses ?? this.isAddedToExpenses,
    );
  }
}
