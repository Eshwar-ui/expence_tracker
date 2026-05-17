class PendingTransaction {
  final String id;
  final double amount;
  final String merchantName;
  final String? suggestedCategory;
  final String transactionType;
  final String
      detectedFrom; // Package name like 'com.google.android.apps.nbu.paisa.user'
  final DateTime detectedAt;
  final String rawNotificationText;
  final String? description;

  PendingTransaction({
    required this.id,
    required this.amount,
    required this.merchantName,
    this.suggestedCategory,
    this.transactionType = 'debit',
    required this.detectedFrom,
    required this.detectedAt,
    required this.rawNotificationText,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'merchantName': merchantName,
      'suggestedCategory': suggestedCategory,
      'transactionType': transactionType,
      'detectedFrom': detectedFrom,
      'detectedAt': detectedAt.toIso8601String(),
      'rawNotificationText': rawNotificationText,
      'description': description,
    };
  }

  factory PendingTransaction.fromMap(Map<String, dynamic> map) {
    return PendingTransaction(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      merchantName: map['merchantName'] as String,
      suggestedCategory: map['suggestedCategory'] as String?,
      transactionType: (map['transactionType'] as String?) ?? 'debit',
      detectedFrom: map['detectedFrom'] as String,
      detectedAt: DateTime.parse(map['detectedAt'] as String),
      rawNotificationText: map['rawNotificationText'] as String,
      description: map['description'] as String?,
    );
  }

  bool get isCredit => transactionType == 'credit';

  String get appName {
    if (detectedFrom.contains('google.android.apps.nbu.paisa')) {
      return 'Google Pay';
    }
    if (detectedFrom.contains('phonepe')) return 'PhonePe';
    if (detectedFrom.contains('paytm')) return 'Paytm';
    if (detectedFrom.contains('bhim')) return 'BHIM UPI';
    if (detectedFrom.contains('sbi')) return 'SBI UPI';
    return 'UPI App';
  }
}
