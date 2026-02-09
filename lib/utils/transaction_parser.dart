class TransactionParser {
  // Comprehensive bank sender patterns
  static const Map<String, String> bankPatterns = {
    'AXIS': 'Axis Bank',
    'HDFC': 'HDFC Bank',
    'ICICI': 'ICICI Bank',
    'SBI': 'State Bank of India',
    'KOTAK': 'Kotak Mahindra Bank',
    'YES': 'Yes Bank',
    'INDUS': 'IndusInd Bank',
    'PNB': 'Punjab National Bank',
    'BOI': 'Bank of India',
    'CANARA': 'Canara Bank',
    'UNION': 'Union Bank',
    'IDBI': 'IDBI Bank',
    'BANDHAN': 'Bandhan Bank',
    'FEDERAL': 'Federal Bank',
    'RBL': 'RBL Bank',
    'DCB': 'DCB Bank',
    'UPI': 'UPI Transaction',
  };

  static const List<String> transactionKeywords = [
    'DEBIT',
    'CREDIT',
    'WITHDRAWAL',
    'DEPOSIT',
    'PURCHASE',
    'PAYMENT',
    'TRANSFER',
    'UPI',
    'NEFT',
    'RTGS',
    'IMPS',
    'ATM',
    'CASH',
    'ONLINE',
    'POS',
    'SWIPE',
    'TRANSACTION',
    'SPENT',
    'RECEIVED',
    'SALARY',
    'REFUND'
  ];

  static List<RegExp> amountPatterns = [
    RegExp(r'RS\.?\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)', caseSensitive: false),
    RegExp(r'₹\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)', caseSensitive: false),
    RegExp(r'INR\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)', caseSensitive: false),
    RegExp(r'(\d+(?:,\d+)*(?:\.\d{1,2})?)\s*RS', caseSensitive: false),
  ];

  static double? extractAmount(String text) {
    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        // Simple heuristic to avoid matching phone numbers as amounts
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0 && amount < 10000000) {
          return amount;
        }
      }
    }
    return null;
  }

  static String extractTransactionType(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('CREDIT') ||
        upper.contains('CREDITED') ||
        upper.contains('RECEIVED') ||
        upper.contains('REWARD') ||
        upper.contains('REFUND') ||
        upper.contains('CASHBACK')) {
      return 'credit';
    }
    return 'debit';
  }

  static String extractBankName(String sender, String body) {
    final upperSender = sender.toUpperCase();
    for (final entry in bankPatterns.entries) {
      if (upperSender.contains(entry.key)) return entry.value;
    }

    final upperBody = body.toUpperCase();
    for (final entry in bankPatterns.entries) {
      if (upperBody.contains(entry.key)) return entry.value;
    }

    return sender.isNotEmpty ? sender : 'Unknown Bank';
  }

  static String extractDescription(String body) {
    // Try to normalize using common merchant names
    return normalizeDescription(body);
  }

  static String normalizeDescription(String raw) {
    final lower = raw.toLowerCase();

    // Merchant Map for quick normalization
    final merchants = {
      'swiggy': 'Swiggy',
      'zomato': 'Zomato',
      'amazon': 'Amazon',
      'flipkart': 'Flipkart',
      'uber': 'Uber',
      'ola': 'Ola',
      'netflix': 'Netflix',
      'hotstar': 'Hotstar',
      'spotify': 'Spotify',
      'jio': 'Jio Recharge',
      'airtel': 'Airtel Recharge',
      'paytm': 'Paytm',
      'gpay': 'Google Pay',
    };

    for (final entry in merchants.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    // Fallback cleanup
    String cleaned = raw
        .replaceAll(RegExp(r'(\d+)'), '')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .trim();
    if (cleaned.length > 30) cleaned = cleaned.substring(0, 30).trim();
    return cleaned.isEmpty ? 'Transaction' : cleaned;
  }

  static String? suggestCategory(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('swiggy') ||
        lower.contains('zomato') ||
        lower.contains('food') ||
        lower.contains('restaurant')) return 'Food';
    if (lower.contains('amazon') ||
        lower.contains('flipkart') ||
        lower.contains('shopping') ||
        lower.contains('myntra')) return 'Shopping';
    if (lower.contains('uber') ||
        lower.contains('ola') ||
        lower.contains('transport') ||
        lower.contains('petrol') ||
        lower.contains('fuel')) return 'Transportation';
    if (lower.contains('jio') ||
        lower.contains('airtel') ||
        lower.contains('recharge') ||
        lower.contains('bill')) return 'Bills';
    if (lower.contains('netflix') ||
        lower.contains('hotstar') ||
        lower.contains('spotify') ||
        lower.contains('movie')) return 'Entertainment';
    if (lower.contains('pharmacy') ||
        lower.contains('hospital') ||
        lower.contains('medical')) return 'Healthcare';
    return null;
  }
}
