/// Utility class to normalize and clean up SMS transaction descriptions
/// into human-readable titles.
class TransactionTitleNormalizer {
  TransactionTitleNormalizer._();

  // ============================================================================
  // MERCHANT DICTIONARY - Maps raw merchant codes to friendly names
  // ============================================================================
  static const Map<String, String> _merchantMap = {
    // Food & Delivery
    'swiggy': 'Swiggy',
    'zomato': 'Zomato',
    'dunzo': 'Dunzo',
    'blinkit': 'Blinkit',
    'zepto': 'Zepto',
    'bigbasket': 'BigBasket',
    'grofers': 'Blinkit',
    'dominos': "Domino's Pizza",
    'pizzahut': 'Pizza Hut',
    'mcdonalds': "McDonald's",
    'burgerking': 'Burger King',
    'kfc': 'KFC',
    'starbucks': 'Starbucks',
    'ccd': 'Cafe Coffee Day',

    // E-commerce
    'amazon': 'Amazon',
    'flipkart': 'Flipkart',
    'myntra': 'Myntra',
    'ajio': 'AJIO',
    'meesho': 'Meesho',
    'nykaa': 'Nykaa',
    'snapdeal': 'Snapdeal',
    'paytmmall': 'Paytm Mall',
    'tatacliq': 'Tata CLiQ',

    // Transport
    'uber': 'Uber',
    'ola': 'Ola',
    'rapido': 'Rapido',
    'irctc': 'Train Ticket (IRCTC)',
    'redbus': 'RedBus',
    'makemytrip': 'MakeMyTrip',
    'goibibo': 'Goibibo',
    'cleartrip': 'Cleartrip',
    'indigo': 'IndiGo Flight',
    'spicejet': 'SpiceJet Flight',
    'vistara': 'Vistara Flight',
    'airindia': 'Air India Flight',

    // Utilities & Bills
    'bescom': 'Electricity Bill (BESCOM)',
    'bses': 'Electricity Bill (BSES)',
    'tatapower': 'Tata Power Bill',
    'adani': 'Adani Electricity',
    'jio': 'Jio Recharge',
    'airtel': 'Airtel Recharge',
    'vi': 'Vi Recharge',
    'vodafone': 'Vi Recharge',
    'idea': 'Vi Recharge',
    'bsnl': 'BSNL Recharge',
    'tatasky': 'Tata Play DTH',
    'dishtv': 'Dish TV',
    'd2h': 'D2H DTH',
    'airtelxstream': 'Airtel Xstream',

    // Entertainment
    'netflix': 'Netflix',
    'hotstar': 'Disney+ Hotstar',
    'primevideo': 'Amazon Prime',
    'spotify': 'Spotify',
    'gaana': 'Gaana',
    'youtube': 'YouTube Premium',
    'bookmyshow': 'BookMyShow',
    'pvr': 'PVR Cinemas',
    'inox': 'INOX Movies',

    // Payments
    'gpay': 'Google Pay',
    'googlepay': 'Google Pay',
    'phonepe': 'PhonePe',
    'paytm': 'Paytm',
    'amazonpay': 'Amazon Pay',
    'mobikwik': 'MobiKwik',
    'freecharge': 'Freecharge',
    'cred': 'CRED',

    // Insurance & Finance
    'lic': 'LIC Premium',
    'policybazaar': 'PolicyBazaar',
    'acko': 'Acko Insurance',
    'zerodha': 'Zerodha',
    'groww': 'Groww',
    'upstox': 'Upstox',
    'angelone': 'Angel One',

    // Healthcare
    'apollo': 'Apollo Pharmacy',
    'netmeds': 'Netmeds',
    'pharmeasy': 'PharmEasy',
    '1mg': '1mg',
    'practo': 'Practo',

    // Grocery & Retail
    'dmart': 'DMart',
    'reliance': 'Reliance',
    'more': 'More Supermarket',
    'spencers': "Spencer's",
    'spar': 'SPAR',
    'walmart': 'Walmart',

    // Fuel
    'iocl': 'Indian Oil',
    'hpcl': 'HP Petrol',
    'bpcl': 'Bharat Petroleum',
    'shell': 'Shell Fuel',
  };

  // ============================================================================
  // JARGON TO REMOVE - Banking/payment terms that add no value
  // ============================================================================
  static const List<String> _jargonWords = [
    'debited',
    'credited',
    'transferred',
    'paid',
    'received',
    'via',
    'upi',
    'imps',
    'neft',
    'rtgs',
    'nach',
    'vpa',
    'ref',
    'refno',
    'txn',
    'txnid',
    'transaction',
    'from',
    'to',
    'for',
    'at',
    'on',
    'by',
    'with',
    'a/c',
    'ac',
    'acct',
    'account',
    'bank',
    'ltd',
    'pvt',
    'pvtltd',
    'private',
    'limited',
    'india',
    'services',
    'solutions',
    'inr',
    'rs',
    'rupees',
    'amount',
    'payment',
    'merchant',
    'successful',
    'success',
    'completed',
    'approved',
    'info',
    'sms',
    'alert',
    'notification',
    'hdfc',
    'icici',
    'sbi',
    'axis',
    'kotak',
    'yes',
    'idfc',
    'rbl',
    'bob',
    'pnb',
    'okicici',
    'okaxis',
    'oksbi',
    'okhdfc',
    'paytm',
    'ybl',
    'apl',
    'ibl',
  ];

  // ============================================================================
  // PATTERNS FOR EXTRACTION
  // ============================================================================
  static final List<RegExp> _extractionPatterns = [
    // "paid to MERCHANT" or "transferred to MERCHANT"
    RegExp(
      r'(?:paid|transferred|sent)\s+to\s+([A-Za-z0-9\s\.\-&]+?)(?:\s+(?:via|ref|vpa|on|for)|$)',
      caseSensitive: false,
    ),

    // "received from SENDER"
    RegExp(
      r'received\s+from\s+([A-Za-z0-9\s\.\-&]+?)(?:\s+(?:via|ref|vpa|on)|$)',
      caseSensitive: false,
    ),

    // "VPA:name@bank" - extract the name part
    RegExp(r'vpa[:\s]*([a-z0-9\.\-]+)@', caseSensitive: false),

    // "at MERCHANT" (for ATM, POS, etc.)
    RegExp(
      r'(?:at|from)\s+([A-Za-z0-9\s\.\-&]+?)(?:\s+(?:atm|pos|ref|on)|$)',
      caseSensitive: false,
    ),

    // "for MERCHANT/PURPOSE"
    RegExp(
      r'for\s+([A-Za-z0-9\s\.\-&]+?)(?:\s+(?:via|ref|on)|$)',
      caseSensitive: false,
    ),
  ];

  // ============================================================================
  // MAIN NORMALIZATION METHOD
  // ============================================================================

  /// Normalizes a raw SMS transaction description into a clean, readable title.
  ///
  /// Example:
  /// ```dart
  /// normalize("Paid to SWIGGY via UPI Ref:1234567890")
  /// // Returns: "Swiggy"
  /// ```
  static String normalize(String rawDescription) {
    if (rawDescription.isEmpty) return 'Transaction';

    String cleaned = rawDescription;

    // Step 1: Try to extract merchant/payee using patterns
    String? extracted = _extractMerchant(cleaned);
    if (extracted != null && extracted.isNotEmpty) {
      cleaned = extracted;
    }

    // Step 2: Remove numbers, special characters, and jargon
    cleaned = _removeJargon(cleaned);

    // Step 3: Look up in merchant dictionary
    cleaned = _mapToFriendlyName(cleaned);

    // Step 4: Clean up and format
    cleaned = _formatTitle(cleaned);

    // Step 5: Fallback if empty
    if (cleaned.isEmpty || cleaned.length < 2) {
      return _getFallbackTitle(rawDescription);
    }

    return cleaned;
  }

  /// Extracts merchant name using regex patterns
  static String? _extractMerchant(String text) {
    for (final pattern in _extractionPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final extracted = match.group(1)?.trim();
        if (extracted != null && extracted.length >= 2) {
          return extracted;
        }
      }
    }
    return null;
  }

  /// Removes banking jargon and noise words
  static String _removeJargon(String text) {
    // Remove numbers (account numbers, ref numbers, amounts)
    text = text.replaceAll(RegExp(r'\d{4,}'), ' ');
    text = text.replaceAll(
      RegExp(r'rs\.?\s*[\d,\.]+', caseSensitive: false),
      ' ',
    );
    text = text.replaceAll(
      RegExp(r'inr\.?\s*[\d,\.]+', caseSensitive: false),
      ' ',
    );

    // Remove special characters but keep spaces
    text = text.replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ');

    // Split into words and filter
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final filteredWords = words.where((word) {
      return word.length > 1 && !_jargonWords.contains(word);
    }).toList();

    return filteredWords.join(' ');
  }

  /// Maps known merchant identifiers to friendly names
  static String _mapToFriendlyName(String text) {
    final lowerText = text.toLowerCase().trim();

    // Direct match
    if (_merchantMap.containsKey(lowerText)) {
      return _merchantMap[lowerText]!;
    }

    // Partial match - check if any merchant key is contained
    for (final entry in _merchantMap.entries) {
      if (lowerText.contains(entry.key)) {
        return entry.value;
      }
    }

    return text;
  }

  /// Formats the title with proper capitalization
  static String _formatTitle(String text) {
    text = text.trim();
    if (text.isEmpty) return text;

    // If it's already a mapped friendly name (contains spaces and proper case)
    if (text.contains(' ') && text[0] == text[0].toUpperCase()) {
      return text;
    }

    // Title case
    return text
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  /// Provides a fallback title based on transaction type indicators
  static String _getFallbackTitle(String rawText) {
    final lower = rawText.toLowerCase();

    if (lower.contains('atm') || lower.contains('cash')) {
      return 'ATM Withdrawal';
    }
    if (lower.contains('pos') || lower.contains('card')) {
      return 'Card Payment';
    }
    if (lower.contains('emi')) {
      return 'EMI Payment';
    }
    if (lower.contains('salary') || lower.contains('credit')) {
      return 'Income';
    }
    if (lower.contains('refund')) {
      return 'Refund';
    }
    if (lower.contains('transfer')) {
      return 'Transfer';
    }

    return 'Transaction';
  }

  // ============================================================================
  // CATEGORY SUGGESTION (BONUS)
  // ============================================================================

  /// Suggests a category based on the merchant/transaction type
  static String? suggestCategory(String rawDescription) {
    final lower = rawDescription.toLowerCase();

    // Food
    if (_containsAny(lower, [
      'swiggy',
      'zomato',
      'dominos',
      'pizza',
      'mcdonalds',
      'kfc',
      'burger',
      'restaurant',
      'food',
      'cafe',
      'coffee',
    ])) {
      return 'Food';
    }

    // Shopping
    if (_containsAny(lower, [
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'meesho',
      'nykaa',
      'shopping',
      'store',
      'mart',
      'retail',
    ])) {
      return 'Shopping';
    }

    // Transport
    if (_containsAny(lower, [
      'uber',
      'ola',
      'rapido',
      'irctc',
      'train',
      'flight',
      'bus',
      'metro',
      'fuel',
      'petrol',
      'diesel',
    ])) {
      return 'Transportation';
    }

    // Bills
    if (_containsAny(lower, [
      'electricity',
      'bescom',
      'water',
      'gas',
      'broadband',
      'wifi',
      'mobile',
      'recharge',
      'postpaid',
      'prepaid',
    ])) {
      return 'Bills';
    }

    // Entertainment
    if (_containsAny(lower, [
      'netflix',
      'hotstar',
      'prime',
      'spotify',
      'movie',
      'cinema',
      'pvr',
      'inox',
      'theatre',
    ])) {
      return 'Entertainment';
    }

    // Healthcare
    if (_containsAny(lower, [
      'pharmacy',
      'medical',
      'hospital',
      'doctor',
      'medicine',
      'apollo',
      'netmeds',
      'pharmeasy',
      '1mg',
    ])) {
      return 'Healthcare';
    }

    // Education
    if (_containsAny(lower, [
      'school',
      'college',
      'university',
      'course',
      'udemy',
      'coursera',
      'fee',
      'tuition',
    ])) {
      return 'Education';
    }

    // Income
    if (_containsAny(lower, [
      'salary',
      'credited',
      'received',
      'refund',
      'cashback',
    ])) {
      return 'Salary';
    }

    return null;
  }

  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }
}
