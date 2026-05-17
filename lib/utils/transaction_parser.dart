class TransactionParser {
  /// Normalizes Mathematical Alphanumeric Characters (used by banks to bypass spam filters)
  /// back to standard ASCII characters so regex patterns can work correctly.
  static String normalizeText(String input) {
    if (input.isEmpty) return input;
    StringBuffer sb = StringBuffer();
    for (int rune in input.runes) {
      if (rune >= 0x1D5A0 && rune <= 0x1D5B9) {
        // Math Sans-Serif Capital
        sb.writeCharCode(rune - 0x1D5A0 + 0x41);
      } else if (rune >= 0x1D5BA && rune <= 0x1D5D3) {
        // Math Sans-Serif Small
        sb.writeCharCode(rune - 0x1D5BA + 0x61);
      } else if (rune >= 0x1D400 && rune <= 0x1D419) {
        // Math Bold Capital
        sb.writeCharCode(rune - 0x1D400 + 0x41);
      } else if (rune >= 0x1D41A && rune <= 0x1D433) {
        // Math Bold Small
        sb.writeCharCode(rune - 0x1D41A + 0x61);
      } else if (rune >= 0x1D434 && rune <= 0x1D44D) {
        // Math Italic Capital
        sb.writeCharCode(rune - 0x1D434 + 0x41);
      } else if (rune >= 0x1D44E && rune <= 0x1D467) {
        // Math Italic Small
        sb.writeCharCode(rune - 0x1D44E + 0x61);
      } else if (rune >= 0x1D5D4 && rune <= 0x1D5ED) {
        // Math Sans-Serif Bold Capital
        sb.writeCharCode(rune - 0x1D5D4 + 0x41);
      } else if (rune >= 0x1D5EE && rune <= 0x1D607) {
        // Math Sans-Serif Bold Small
        sb.writeCharCode(rune - 0x1D5EE + 0x61);
      } else if (rune >= 0x1D670 && rune <= 0x1D689) {
        // Math Monospace Capital
        sb.writeCharCode(rune - 0x1D670 + 0x41);
      } else if (rune >= 0x1D68A && rune <= 0x1D6A3) {
        // Math Monospace Small
        sb.writeCharCode(rune - 0x1D68A + 0x61);
      } else if (rune >= 0x1D56C && rune <= 0x1D585) {
        // Math Bold Italic Capital
        sb.writeCharCode(rune - 0x1D56C + 0x41);
      } else if (rune >= 0x1D586 && rune <= 0x1D59F) {
        // Math Bold Italic Small
        sb.writeCharCode(rune - 0x1D586 + 0x61);
      } else if (rune >= 0x1D608 && rune <= 0x1D621) {
        // Math Sans-Serif Italic Capital
        sb.writeCharCode(rune - 0x1D608 + 0x41);
      } else if (rune >= 0x1D622 && rune <= 0x1D63B) {
        // Math Sans-Serif Italic Small
        sb.writeCharCode(rune - 0x1D622 + 0x61);
      } else if (rune >= 0x1D63C && rune <= 0x1D655) {
        // Math Sans-Serif Bold Italic Capital
        sb.writeCharCode(rune - 0x1D63C + 0x41);
      } else if (rune >= 0x1D656 && rune <= 0x1D66F) {
        // Math Sans-Serif Bold Italic Small
        sb.writeCharCode(rune - 0x1D656 + 0x61);
      } else {
        sb.writeCharCode(rune);
      }
    }
    return sb.toString();
  }

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
    'AMEX': 'American Express',
    'CITI': 'Citibank',
    'HSBC': 'HSBC Bank',
    'PAYTM': 'Paytm',
    'PHONEPE': 'PhonePe',
    'GPAY': 'Google Pay',
  };

  static bool isBankMessage(String sender, String body) {
    final upperSender = sender.toUpperCase();
    final upperBody = body.toUpperCase();

    // 1. Check strict bank sender patterns
    for (final bank in bankPatterns.keys) {
      if (upperSender.contains(bank) || upperBody.contains(bank)) return true;
    }

    // 2. Dynamic check based on financial indicators (A/c, Acct, Card) + Action
    // Finds A/C, Acct, Card, VPA followed by numbers/X
    final hasAccountIndicator = RegExp(
            r'(A/C|ACCT|ACCOUNT|CARD|VPA)\s*(NO|ENDING|ENDING WITH)?\s*[:\-\*]*[X\d]+',
            caseSensitive: false)
        .hasMatch(body);

    // Finds common transactional action words
    final hasFinancialAction = RegExp(
            r'(DEBITED|CREDITED|WITHDRAWN|DEPOSITED|SPENT|PAID|DEDUCTED|RECEIVED|REFUNDED|SENT)',
            caseSensitive: false)
        .hasMatch(body);

    if (hasAccountIndicator && hasFinancialAction) {
      return true;
    }

    // 3. Catch specific bank names buried in body (like "Union Bank of India")
    final bankNamesExplicit = RegExp(
        r'(Union Bank of India|State Bank of India|Bank of Baroda|HDFC Bank|ICICI Bank)',
        caseSensitive: false);
    if (bankNamesExplicit.hasMatch(body) && hasFinancialAction) {
      return true;
    }

    // 4. Very generic transaction regex (Txn, Ref)
    if (RegExp(r'(TXN|REF|UTR)\s*(NO)?\s*[:\-]?\s*\d+', caseSensitive: false)
        .hasMatch(body)) {
      return true;
    }

    return false;
  }

  static List<RegExp> amountPatterns = [
    // Standard formats: Rs. 100, RS 100, Rs100, INR 100, ₹ 100, 100.00 RS, Rs:10.00
    RegExp(r'(?:RS\.?|INR|₹|Rs:?)\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)',
        caseSensitive: false),
    RegExp(r'(\d+(?:,\d+)*(?:\.\d{1,2})?)\s*(?:RS|INR|₹|Rs:?)',
        caseSensitive: false),
    // Contextual amounts: debited by 100, spent 100
    RegExp(
        r'(?:debited|credited|spent|paid|deducted|received|amount)\s*(?:by|of|is|for)?\s*(?:RS\.?|INR|₹|Rs:?)?\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)',
        caseSensitive: false),
    // Amount followed by "debited" or "credited"
    RegExp(r'(\d+(?:,\d+)*(?:\.\d{1,2})?)\s*(?:debited|credited|spent|paid)',
        caseSensitive: false),
  ];

  static get transactionKeywords => null;

  static double? extractAmount(String text) {
    // Prevent confusing account numbers/card numbers with transaction amounts
    // We sanitize the text by hiding digits that are associated with account indicators
    String safeText = text.replaceAll(
        RegExp(
            r'(?:A/C|ACCT|ACCOUNT|CARD|VPA)\s*(?:NO|ENDING|ENDING WITH)?\s*[:\-\*xX\s]*\d+',
            caseSensitive: false),
        'ACC_XX');
    // Also hide any floating grouped digits usually hiding account info (e.g. *1234, xx1234)
    safeText = safeText.replaceAll(
        RegExp(r'(?:[\*xX]{2,})\d+', caseSensitive: false), 'XX_NUM');

    // Some formats say "amount 1234 debited", but some just say "1234 debited".
    // If it's "*1234 debited", it's an account number.
    safeText = safeText.replaceAll(RegExp(r'\*\d+'), 'XX');

    for (final pattern in amountPatterns) {
      final matches = pattern.allMatches(safeText);
      for (final match in matches) {
        // Simple heuristic to avoid matching phone numbers as amounts
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0 && amount < 1000000) {
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
        upper.contains('ADDED') ||
        upper.contains('CASHBACK') ||
        upper.contains('DEPOSITED')) {
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

    // Dynamic Sender Extraction (e.g., AD-HDFCBK -> HDFCBK)
    if (sender.contains('-')) {
      final parts = sender.split('-');
      if (parts.length > 1 && parts[1].length > 2) {
        return parts[1];
      }
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
        lower.contains('restaurant')) {
      return 'Food';
    }
    if (lower.contains('amazon') ||
        lower.contains('flipkart') ||
        lower.contains('shopping') ||
        lower.contains('myntra')) {
      return 'Shopping';
    }
    if (lower.contains('uber') ||
        lower.contains('ola') ||
        lower.contains('transport') ||
        lower.contains('petrol') ||
        lower.contains('fuel')) {
      return 'Transportation';
    }
    if (lower.contains('jio') ||
        lower.contains('airtel') ||
        lower.contains('recharge') ||
        lower.contains('bill')) {
      return 'Bills';
    }
    if (lower.contains('netflix') ||
        lower.contains('hotstar') ||
        lower.contains('spotify') ||
        lower.contains('movie')) {
      return 'Entertainment';
    }
    if (lower.contains('pharmacy') ||
        lower.contains('hospital') ||
        lower.contains('medical')) {
      return 'Healthcare';
    }
    return null;
  }
}
