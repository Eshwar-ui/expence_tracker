class ParsingResult {
  final double? amount;
  final String? transactionType; // 'debit' | 'credit'
  final String? merchant;
  final double confidence; // 0.0 - 1.0
  final String? source; // package name or sender identifier

  const ParsingResult({
    required this.amount,
    required this.transactionType,
    required this.merchant,
    required this.confidence,
    this.source,
  });

  bool get isValid => amount != null && confidence > 0.0;
}

/// Hard-rejection rules. Anything matching these patterns is NOT a financial
/// transaction and should be dropped before scoring.
class RejectionRules {
  // OTPs, login codes, verification PINs.
  static final RegExp _otp = RegExp(
    r'\b(otp|one[\s-]?time[\s-]?password|verification\s+code|login\s+code|'
    r'security\s+code|auth\s+code|access\s+code|confirmation\s+code|'
    r'do\s+not\s+share|never\s+share|don’t\s+share)\b',
    caseSensitive: false,
  );
  // Standalone 4-8 digit codes accompanied by "is" / ":" — classic OTP shape.
  static final RegExp _codeShape = RegExp(
    r'\b(code|pin|otp)\s*(is|:)\s*\d{4,8}\b',
    caseSensitive: false,
  );

  // Promotional / marketing.
  static final RegExp _promo = RegExp(
    r'\b(offer|discount|sale|deal|flat\s*\d+%|upto\s*\d+%|coupon|promo\s*code|'
    r'limited\s+time|hurry|expires?\s+today|click\s+here|t&c|t\s*and\s*c\s+apply|'
    r'subscribe|unsubscribe|advertisement|sponsored)\b',
    caseSensitive: false,
  );

  // Cart / wishlist / reminder — NOT a completed transaction.
  static final RegExp _cartReminder = RegExp(
    r'\b(cart|wishlist|waiting\s+for\s+you|items?\s+in\s+your\s+cart|'
    r'left\s+in\s+your\s+cart|complete\s+your\s+(order|purchase|payment)|'
    r'don’?t\s+miss\s+out|order\s+now|buy\s+now|shop\s+now|grab\s+now)\b',
    caseSensitive: false,
  );

  // Balance / statement summaries (informational, not a new transaction).
  static final RegExp _balanceOnly = RegExp(
    r'\b(available\s+(bal|balance)|a\s*v\s*a\s*i\s*l\s*\.?\s*bal|'
    r'closing\s+balance|opening\s+balance|min(imum)?\s+balance|'
    r'statement\s+(generated|ready)|due\s+(date|on))\b',
    caseSensitive: false,
  );

  // Common DLT promotional/service header prefixes used by Indian carriers
  // for marketing SMS. Transactional SMS use TX-/JX-/JK- typically, while
  // promotional use AD-/VM-/VK-/AX-/TM-/BP-/BZ-/DM-/DZ- etc.
  static final RegExp _promoHeader = RegExp(
    r'^(AD|VM|VK|AX|TM|BP|BZ|DM|DZ|PM|PR)[-\s][A-Z0-9]{2,}',
    caseSensitive: false,
  );

  /// Returns the rejection reason (e.g. "otp", "promo") or null if nothing
  /// matches. Caller decides whether to drop or downgrade.
  static String? rejectionReason(
    String text, {
    String? title,
    String? sender,
  }) {
    final combined = '${title ?? ''} $text'.trim();

    if (_otp.hasMatch(combined) || _codeShape.hasMatch(combined)) {
      return 'otp';
    }
    if (_cartReminder.hasMatch(combined)) return 'cart_reminder';
    if (_promo.hasMatch(combined)) return 'promo';
    // Balance-only message: only reject if there's no debit/credit keyword,
    // because a real txn SMS often includes the balance alongside.
    if (_balanceOnly.hasMatch(combined) &&
        !RegExp(r'\b(debited|credited|spent|paid|withdrawn|deposited|received|charged)\b',
                caseSensitive: false)
            .hasMatch(combined)) {
      return 'balance_only';
    }
    if (sender != null && _promoHeader.hasMatch(sender)) {
      return 'promo_sender';
    }
    return null;
  }
}

class NotificationParsing {
  static const List<String> _creditKeywords = [
    'credited',
    'credit',
    'received',
    'deposited',
    'cr',
    'refund',
    'cashback',
    'reversal',
    'reversed',
  ];

  static const List<String> _debitKeywords = [
    'debited',
    'debit',
    'spent',
    'paid',
    'payment',
    'purchase',
    'withdrawn',
    'withdrawal',
    'dr',
    'charged',
    'deducted',
    'transfer',
    'sent',
  ];

  static final List<RegExp> _amountPatterns = [
    RegExp(
      r'(?:rs\.?:?|inr[:.]?|\u20b9)\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(?:rs\.?|inr|\u20b9)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:amount|amt)\s*(?:of|is|:)?\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:debited|credited|spent|paid|payment|purchase|withdrawn|received|charged|deducted)\s*(?:for|of|by)?\s*(?:rs\.?:?|inr[:.]?|\u20b9)?\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:dr|cr)\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _merchantPatterns = [
    RegExp(r'\bto\s+([a-z0-9][a-z0-9 &._@/\-]{2,})', caseSensitive: false),
    RegExp(r'\bat\s+([a-z0-9][a-z0-9 &._@/\-]{2,})', caseSensitive: false),
    RegExp(r'\bfrom\s+([a-z0-9][a-z0-9 &._@/\-]{2,})', caseSensitive: false),
    RegExp(r'\bmerchant[:\s]+([a-z0-9][a-z0-9 &._@/\-]{2,})',
        caseSensitive: false),
    RegExp(r'\bpayee[:\s]+([a-z0-9][a-z0-9 &._@/\-]{2,})',
        caseSensitive: false),
    RegExp(r'\bupi[:/\- ]+([a-z0-9@._-]{3,})', caseSensitive: false),
    RegExp(r'[-–]\s*([a-z][a-z &.]{2,})$', caseSensitive: false),
  ];

  static ParsingResult parse(String text, {String? title}) {
    final combined = _normalize('$title $text');

    final amountInfo = _extractAmount(combined);
    final amount = amountInfo.amount;
    final amountHasContext = amountInfo.hasContext;

    final type = _extractType(combined);
    final merchant = _extractMerchant(combined, preferredType: type);

    double confidence = 0.0;
    if (amount != null) {
      confidence += 0.4;
      if (amountHasContext) confidence += 0.15;
    }
    if (type != null) confidence += 0.25;
    if (merchant != null) confidence += 0.15;

    // Require at least 2 strong signals. Amount alone is not enough — too many
    // promo/balance notifications contain a currency amount.
    final signalCount = [
      amount != null && amountHasContext,
      type != null,
      merchant != null,
    ].where((s) => s).length;
    if (signalCount < 2) confidence = (confidence * 0.5).clamp(0.0, 1.0);

    if (confidence > 1.0) confidence = 1.0;

    return ParsingResult(
      amount: amount,
      transactionType: type,
      merchant: merchant,
      confidence: confidence,
      source: null,
    );
  }

  static String _normalize(String input) {
    return input
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .trim();
  }

  static _AmountResult _extractAmount(String text) {
    for (final pattern in _amountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final raw = match.group(1)?.replaceAll(',', '') ?? '';
        final amount = double.tryParse(raw);
        if (amount != null && amount > 0 && amount < 100000000) {
          final hasCurrency = RegExp(
            r'(rs\.?|inr|\u20b9)',
            caseSensitive: false,
          ).hasMatch(match.group(0) ?? '');
          final hasKeyword = RegExp(
                  r'(debited|credited|spent|paid|payment|purchase|withdrawn|received|charged|deducted|dr|cr|amount|amt)',
                  caseSensitive: false)
              .hasMatch(match.group(0) ?? '');
          return _AmountResult(
              amount: amount, hasContext: hasCurrency || hasKeyword);
        }
      }
    }
    return const _AmountResult(amount: null, hasContext: false);
  }

  static String? _extractType(String text) {
    final lower = text.toLowerCase();

    final hasCredit = _creditKeywords.any(lower.contains);
    final hasDebit = _debitKeywords.any(lower.contains);

    if (hasCredit && !hasDebit) return 'credit';
    if (hasDebit && !hasCredit) return 'debit';

    if (lower.contains('credited') || lower.contains(' cr ')) return 'credit';
    if (lower.contains('debited') || lower.contains(' dr ')) return 'debit';
    if (lower.contains('refund') || lower.contains('cashback')) return 'credit';
    if (lower.contains('spent') ||
        lower.contains('paid') ||
        lower.contains('purchase')) {
      return 'debit';
    }

    return null;
  }

  static String? _extractMerchant(String text, {String? preferredType}) {
    for (final pattern in _merchantPatterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final raw = match.group(1) ?? '';
      final cleaned = _sanitizeMerchant(raw);
      if (cleaned != null) return cleaned;
    }

    if (preferredType == 'credit') {
      final fromMatch = RegExp(r'\bfrom\s+([a-z0-9][a-z0-9 &._@/\-]{2,})',
              caseSensitive: false)
          .firstMatch(text);
      if (fromMatch != null) {
        return _sanitizeMerchant(fromMatch.group(1) ?? '');
      }
    }

    return null;
  }

  static String? _sanitizeMerchant(String raw) {
    var cleaned = raw;

    cleaned = cleaned.split(RegExp(r'[;,.]')).first;
    cleaned = cleaned.replaceAll(
        RegExp(
            r'\s+(ref|rrn|utr|txn|txnid|id|bal|available|avl|a/c|ac|account)\b.*$',
            caseSensitive: false),
        '');
    cleaned = cleaned.replaceAll(
        RegExp(r'^(upi|imps|neft|rtgs|pos)\s*', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.length < 3) return null;
    return cleaned;
  }
}

class _AmountResult {
  final double? amount;
  final bool hasContext;

  const _AmountResult({required this.amount, required this.hasContext});
}

class ValidationResult {
  final bool isValid;
  final bool isDuplicate;
  final bool isLowConfidence;
  final List<String> reasons;

  const ValidationResult({
    required this.isValid,
    required this.isDuplicate,
    required this.isLowConfidence,
    required this.reasons,
  });

  static const ValidationResult ok = ValidationResult(
    isValid: true,
    isDuplicate: false,
    isLowConfidence: false,
    reasons: <String>[],
  );
}

class NotificationValidation {
  static const double defaultMinConfidence = 0.75;
  static const double maxAmount = 100000000;

  static ValidationResult validate(
    ParsingResult result, {
    required int timestamp,
    required String source,
    double minConfidence = defaultMinConfidence,
    double? amount,
    bool duplicateFound = false,
  }) {
    final reasons = <String>[];

    final resolvedAmount = amount ?? result.amount;
    if (resolvedAmount == null || resolvedAmount <= 0 || resolvedAmount.isNaN) {
      reasons.add('invalid_amount');
    } else if (resolvedAmount > maxAmount) {
      reasons.add('amount_out_of_range');
    }

    if (timestamp <= 0) {
      reasons.add('invalid_timestamp');
    }

    if (source.trim().isEmpty) {
      reasons.add('invalid_source');
    }

    if (result.confidence < minConfidence) {
      reasons.add('low_confidence');
    }

    if (duplicateFound) {
      reasons.add('duplicate');
    }

    final isLowConfidence = reasons.contains('low_confidence');
    final isDuplicate = reasons.contains('duplicate');
    final isValid = reasons.isEmpty;

    return ValidationResult(
      isValid: isValid,
      isDuplicate: isDuplicate,
      isLowConfidence: isLowConfidence,
      reasons: reasons,
    );
  }

  static String duplicateKey({
    required int timestamp,
    required double amount,
    required String source,
  }) {
    final roundedAmount = amount.toStringAsFixed(2);
    return '${timestamp}_${roundedAmount}_${source.toLowerCase()}';
  }
}

/*
Unit-test-like examples:

1) "Rs. 1,250.00 debited from a/c XXXX1234 to SWIGGY Bangalore"
   => amount: 1250.00, type: debit, merchant: "SWIGGY Bangalore"

2) "INR 3,999 credited to your account from AMAZON PAY"
   => amount: 3999.00, type: credit, merchant: "AMAZON PAY"

3) "Payment of 499 at NETFLIX via UPI/NetflixIndia"
   => amount: 499.00, type: debit, merchant: "NETFLIX"

4) "You spent ₹215.50 at Starbucks. Avl bal: ₹12,340.00"
   => amount: 215.50, type: debit, merchant: "Starbucks"

5) "Refund of Rs 199 received from ZOMATO"
   => amount: 199.00, type: credit, merchant: "ZOMATO"

6) "UPI/ABCSTORE@HDFC debited by 850"
   => amount: 850.00, type: debit, merchant: "ABCSTORE@HDFC"

Validation examples:

1) duplicateKey(timestamp: 1700000000000, amount: 499, source: "com.paytm")
   => "1700000000000_499.00_com.paytm"

2) validate(result: ParsingResult(amount: 0, transactionType: "debit", merchant: "X", confidence: 0.9),
            timestamp: 1700000000000, source: "com.bank")
   => reasons: ["invalid_amount"]

3) validate(result: ParsingResult(amount: 120, transactionType: "debit", merchant: "Y", confidence: 0.4),
            timestamp: 1700000000000, source: "com.bank")
   => reasons: ["low_confidence"]

4) validate(result: ParsingResult(amount: 120, transactionType: "debit", merchant: "Y", confidence: 0.9),
            timestamp: 0, source: "com.bank")
   => reasons: ["invalid_timestamp"]

5) validate(result: ParsingResult(amount: 120, transactionType: "debit", merchant: "Y", confidence: 0.9),
            timestamp: 1700000000000, source: "", duplicateFound: true)
   => reasons: ["invalid_source", "duplicate"]
*/
