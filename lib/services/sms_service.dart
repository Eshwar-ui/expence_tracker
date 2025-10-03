import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction_sms.dart';

class SMSService {
  // Comprehensive bank sender patterns
  static const Map<String, String> bankPatterns = {
    // Major Indian Banks
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
    'SOUTH': 'South Indian Bank',
    'CITY': 'City Union Bank',
    'KARUR': 'Karur Vysya Bank',
    'TMB': 'Tamilnad Mercantile Bank',
    'DCB': 'DCB Bank',
    'RBL': 'RBL Bank',
    'LAKSHMI': 'Lakshmi Vilas Bank',
    'DHANLAXMI': 'Dhanlaxmi Bank',
    'JAMMU': 'Jammu & Kashmir Bank',
    'ORIENTAL': 'Oriental Bank of Commerce',
    'VIJAYA': 'Vijaya Bank',
    'ANDHRA': 'Andhra Bank',
    'CORPORATION': 'Corporation Bank',
    'SYNDICATE': 'Syndicate Bank',
    'UCO': 'UCO Bank',
    'CENTRAL': 'Central Bank of India',
    'INDIAN': 'Indian Bank',
    'BANK': 'Bank',
    'CARD': 'Card',
    'CREDIT': 'Credit',
    'DEBIT': 'Debit',
  };

  // Transaction keywords for better filtering
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
    'REFUND',
    'CASHBACK',
    'REWARD',
    'BONUS',
  ];

  // Amount patterns for better extraction
  static List<RegExp> amountPatterns = [
    RegExp(r'RS\.?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)', caseSensitive: false),
    RegExp(r'RS:\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)', caseSensitive: false),
    RegExp(r'INR\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)', caseSensitive: false),
    RegExp(r'₹\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)', caseSensitive: false),
    RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*RS', caseSensitive: false),
    RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*INR', caseSensitive: false),
    RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*₹', caseSensitive: false),
    RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*/-', caseSensitive: false),
  ];

  bool _looksLikePhoneOrRef(String body, Match match) {
    final matchText = match.group(1) ?? '';
    final digitsOnly = matchText.replaceAll(RegExp(r'[^0-9]'), '');
    // Heuristic: 10+ digits without separators is likely a phone/ref number
    if (digitsOnly.length >= 10 &&
        !matchText.contains(',') &&
        !matchText.contains('.')) {
      return true;
    }
    // Look at nearby context for tokens that imply IDs
    final start = match.start;
    final end = match.end;
    final contextStart = (start - 12) < 0 ? 0 : (start - 12);
    final contextEnd = (end + 12) > body.length ? body.length : (end + 12);
    final context = body.substring(contextStart, contextEnd).toUpperCase();
    const badTokens = [
      'REF',
      'TXN',
      'TRANSACTION',
      'UPI',
      'ID',
      'A/C',
      'ACC',
      'ACCOUNT',
      'CARD',
      'NO',
      'OTP',
      'PH',
      'PHONE',
    ];
    return badTokens.any((t) => context.contains(t));
  }

  // Date patterns for better date extraction
  static List<RegExp> datePatterns = [
    RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{4})'), // DD-MM-YYYY or DD/MM/YYYY
    RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})'), // YYYY-MM-DD or YYYY/MM/DD
    RegExp(
      r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})',
      caseSensitive: false,
    ), // DD MMM YYYY
    RegExp(
      r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2}),?\s+(\d{4})',
      caseSensitive: false,
    ), // MMM DD, YYYY
  ];

  // Check if SMS permission is granted
  Future<bool> hasSMSPermission() async {
    try {
      final status = await Permission.sms.status;
      return status.isGranted;
    } catch (e) {
      print('Error checking SMS permission: $e');
      return false;
    }
  }

  // Request SMS permission
  Future<bool> requestSMSPermission() async {
    try {
      final status = await Permission.sms.request();
      return status.isGranted;
    } catch (e) {
      print('Error requesting SMS permission: $e');
      return false;
    }
  }

  // Get recent SMS messages using another_telephony
  Future<List<SmsMessage>> getRecentSMS({int limit = 100}) async {
    try {
      print('🔍 Checking SMS permission...');
      if (!await hasSMSPermission()) {
        print('❌ SMS permission not granted');
        throw Exception('SMS permission not granted');
      }
      print('✅ SMS permission granted');

      print('📱 Initializing Telephony...');
      final Telephony telephony = Telephony.instance;

      print('📨 Fetching SMS messages...');
      final List<SmsMessage> messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      print('📊 Total SMS messages fetched: ${messages.length}');

      // Log first few messages for debugging
      for (int i = 0; i < (messages.length > 3 ? 3 : messages.length); i++) {
        final msg = messages[i];
        print(
          '📧 SMS ${i + 1}: From: ${msg.address}, Body: ${msg.body?.substring(0, (msg.body?.length ?? 0) > 50 ? 50 : msg.body?.length ?? 0)}...',
        );
      }

      // If the API does not support a 'count' parameter, limit manually
      final limitedMessages = messages.take(limit).toList();
      print(
        '📋 Returning ${limitedMessages.length} messages (limited to $limit)',
      );

      return limitedMessages;
    } catch (e) {
      print('❌ Error reading SMS: $e');
      throw Exception('Failed to read SMS: $e');
    }
  }

  // Enhanced filtering for bank-related SMS messages
  List<SmsMessage> filterBankSMS(List<SmsMessage> messages) {
    print(
      '🔍 Filtering ${messages.length} SMS messages for bank transactions...',
    );

    final bankMessages = messages.where((message) {
      final sender = message.address?.toUpperCase() ?? '';
      final body = message.body?.toUpperCase() ?? '';

      // Check if sender contains bank keywords
      final isBankSender = bankPatterns.keys.any(
        (bank) => sender.contains(bank),
      );

      // Check if message contains transaction keywords
      final hasTransactionKeywords = transactionKeywords.any(
        (keyword) => body.contains(keyword),
      );

      // Additional checks for common patterns
      final hasAmountPattern = amountPatterns.any(
        (pattern) => pattern.hasMatch(body),
      );

      // Check for common bank message patterns
      final hasBankPattern =
          body.contains('ACCOUNT') ||
          body.contains('A/C') ||
          body.contains('BALANCE') ||
          body.contains('BAL') ||
          body.contains('AVAILABLE') ||
          body.contains('CURRENT');

      final isBankMessage =
          (isBankSender && hasTransactionKeywords) ||
          (isBankSender && hasAmountPattern) ||
          (isBankSender && hasBankPattern);

      // Log bank messages for debugging
      if (isBankMessage) {
        print(
          '🏦 Bank SMS found: From: $sender, Body: ${body.substring(0, body.length > 50 ? 50 : body.length)}...',
        );
      }

      return isBankMessage;
    }).toList();

    print(
      '📊 Filtered ${bankMessages.length} bank-related messages from ${messages.length} total messages',
    );
    return bankMessages;
  }

  // Enhanced parsing of SMS message to extract transaction details
  TransactionSMS? parseTransactionSMS(SmsMessage message) {
    try {
      final body = message.body ?? '';
      final sender = message.address ?? '';

      print('🔍 Parsing SMS from: $sender');
      print('📝 SMS Body: $body');

      // Extract bank name from sender
      final bankName = _extractBankName(sender);
      print('🏦 Bank Name: $bankName');

      // Extract transaction type
      final transactionType = _extractTransactionType(body);
      print('💳 Transaction Type: $transactionType');

      // Extract amount
      final amount = _extractAmount(body);
      print('💰 Amount: $amount');
      if (amount == null || amount <= 0) {
        print('❌ No valid amount found, skipping transaction');
        return null;
      }

      // Extract date
      final date = _extractDate(
        body,
        message.date != null
            ? DateTime.fromMillisecondsSinceEpoch(message.date!)
            : null,
      );
      print('📅 Date: $date');

      // Extract description
      final description = _extractDescription(body);
      print('📄 Description: $description');

      // Extract balance
      final balance = _extractBalance(body);
      print('💵 Balance: $balance');

      // Extract account number
      final accountNumber = _extractAccountNumber(body);
      print('🔢 Account Number: $accountNumber');

      // Extract reference number
      final referenceNumber = _extractReferenceNumber(body);
      print('🔗 Reference Number: $referenceNumber');

      print('✅ Successfully parsed transaction!');
      return TransactionSMS(
        id: '${message.date != null ? message.date : ''}_${message.address}',
        bankName: bankName,
        accountNumber: accountNumber,
        transactionType: transactionType,
        amount: amount,
        date: date,
        description: description,
        balance: balance,
        originalMessage: body,
        sender: sender,
        referenceNumber: referenceNumber,
      );
    } catch (e) {
      print('❌ Error parsing SMS: $e');
      return null;
    }
  }

  // Enhanced bank name extraction
  String _extractBankName(String sender) {
    final upperSender = sender.toUpperCase();

    // Check for exact matches first
    for (final entry in bankPatterns.entries) {
      if (upperSender.contains(entry.key)) {
        return entry.value;
      }
    }

    // Check for partial matches
    if (upperSender.contains('HDFC')) return 'HDFC Bank';
    if (upperSender.contains('ICICI')) return 'ICICI Bank';
    if (upperSender.contains('SBI')) return 'State Bank of India';
    if (upperSender.contains('AXIS')) return 'Axis Bank';
    if (upperSender.contains('KOTAK')) return 'Kotak Mahindra Bank';
    if (upperSender.contains('YES')) return 'Yes Bank';
    if (upperSender.contains('INDUS')) return 'IndusInd Bank';
    if (upperSender.contains('PNB')) return 'Punjab National Bank';
    if (upperSender.contains('BOI')) return 'Bank of India';
    if (upperSender.contains('CANARA')) return 'Canara Bank';
    if (upperSender.contains('UNION')) return 'Union Bank';
    if (upperSender.contains('UNIONB')) return 'Union Bank';
    if (upperSender.contains('IDBI')) return 'IDBI Bank';
    if (upperSender.contains('BANDHAN')) return 'Bandhan Bank';
    if (upperSender.contains('FEDERAL')) return 'Federal Bank';
    if (upperSender.contains('RBL')) return 'RBL Bank';
    if (upperSender.contains('DCB')) return 'DCB Bank';

    return sender.isNotEmpty ? sender : 'Unknown Bank';
  }

  // Enhanced transaction type extraction
  String _extractTransactionType(String body) {
    final upperBody = body.toUpperCase();

    // Credit indicators
    if (upperBody.contains('CREDIT') ||
        upperBody.contains('CREDITED') ||
        upperBody.contains('DEPOSIT') ||
        upperBody.contains('RECEIVED') ||
        upperBody.contains('SALARY') ||
        upperBody.contains('REFUND') ||
        upperBody.contains('CASHBACK') ||
        upperBody.contains('REWARD') ||
        upperBody.contains('BONUS') ||
        upperBody.contains('TRANSFER IN')) {
      return 'credit';
    }

    // Debit indicators
    if (upperBody.contains('DEBIT') ||
        upperBody.contains('DEBITED') ||
        upperBody.contains('WITHDRAWAL') ||
        upperBody.contains('PURCHASE') ||
        upperBody.contains('PAYMENT') ||
        upperBody.contains('SPENT') ||
        upperBody.contains('TRANSFER OUT') ||
        upperBody.contains('ATM') ||
        upperBody.contains('POS') ||
        upperBody.contains('SWIPE')) {
      return 'debit';
    }

    return 'debit'; // Default to debit
  }

  // Enhanced amount extraction
  double? _extractAmount(String body) {
    try {
      print('🔍 Looking for amount in: $body');
      for (int i = 0; i < amountPatterns.length; i++) {
        final pattern = amountPatterns[i];
        print('📋 Trying pattern ${i + 1}: ${pattern.pattern}');
        final match = pattern.firstMatch(body);
        if (match != null) {
          print('✅ Pattern ${i + 1} matched: ${match.group(0)}');
          final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
          print('💰 Extracted amount string: $amountStr');
          // Filter out phones/reference-like matches
          if (_looksLikePhoneOrRef(body, match)) {
            print('🚫 Discarded as phone/reference-like number');
            continue;
          }
          final amount = double.tryParse(amountStr);
          print('💵 Parsed amount: $amount');
          if (amount != null && amount > 0) {
            print('✅ Valid amount found: $amount');
            return amount;
          }
        } else {
          print('❌ Pattern ${i + 1} did not match');
        }
      }
      print('❌ No amount patterns matched');
      return null;
    } catch (e) {
      print('❌ Error extracting amount: $e');
      return null;
    }
  }

  // Enhanced date extraction
  DateTime _extractDate(String body, DateTime? messageDate) {
    try {
      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(body);
        if (match != null) {
          try {
            if (pattern == datePatterns[0]) {
              // DD-MM-YYYY
              final day = int.parse(match.group(1)!);
              final month = int.parse(match.group(2)!);
              final year = int.parse(match.group(3)!);
              return DateTime(year, month, day);
            } else if (pattern == datePatterns[1]) {
              // YYYY-MM-DD
              final year = int.parse(match.group(1)!);
              final month = int.parse(match.group(2)!);
              final day = int.parse(match.group(3)!);
              return DateTime(year, month, day);
            } else if (pattern == datePatterns[2]) {
              // DD MMM YYYY
              final day = int.parse(match.group(1)!);
              final month = _getMonthNumber(match.group(2)!);
              final year = int.parse(match.group(3)!);
              return DateTime(year, month, day);
            } else if (pattern == datePatterns[3]) {
              // MMM DD, YYYY
              final month = _getMonthNumber(match.group(1)!);
              final day = int.parse(match.group(2)!);
              final year = int.parse(match.group(3)!);
              return DateTime(year, month, day);
            }
          } catch (e) {
            continue;
          }
        }
      }
      return messageDate ?? DateTime.now();
    } catch (e) {
      print('Error extracting date: $e');
      return messageDate ?? DateTime.now();
    }
  }

  // Helper method to get month number from month name
  int _getMonthNumber(String monthName) {
    final months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    return months[monthName.toLowerCase()] ?? 1;
  }

  // Enhanced description extraction
  String _extractDescription(String body) {
    try {
      String description = body;

      // Remove bank-specific prefixes
      final prefixes = [
        'Dear Customer,',
        'Dear Cardholder,',
        'Dear User,',
        'Transaction Alert:',
        'Payment Alert:',
        'Purchase Alert:',
        'Debit Alert:',
        'Credit Alert:',
        'Transaction:',
        'Payment:',
        'Purchase:',
        'Transfer:',
        'UPI Payment:',
        'ATM Transaction:',
        'POS Transaction:',
        'Online Transaction:',
        'Mobile Banking:',
        'Internet Banking:',
        'SMS Alert:',
        'Bank Alert:',
        'Account Alert:',
        'Card Alert:',
      ];

      for (final prefix in prefixes) {
        if (description.toUpperCase().contains(prefix.toUpperCase())) {
          description = description.substring(
            description.toUpperCase().indexOf(prefix.toUpperCase()) +
                prefix.length,
          );
          break;
        }
      }

      // Extract text between amount and balance
      final amountPattern = RegExp(
        r'RS\.?\s*\d+(?:,\d{3})*(?:\.\d{1,2})?',
        caseSensitive: false,
      );
      final balancePattern = RegExp(
        r'BAL\s*RS\.?\s*\d+(?:,\d{3})*(?:\.\d{1,2})?',
        caseSensitive: false,
      );

      final amountMatch = amountPattern.firstMatch(description);
      final balanceMatch = balancePattern.firstMatch(description);

      if (amountMatch != null && balanceMatch != null) {
        final start = amountMatch.end;
        final end = balanceMatch.start;
        if (end > start) {
          description = description.substring(start, end).trim();
        }
      }

      // Clean up the description
      description = description
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'[^\w\s\-\.@]'), '')
          .trim();

      if (description.isEmpty) {
        description = 'Transaction';
      }

      return description.length > 50
          ? '${description.substring(0, 50)}...'
          : description;
    } catch (e) {
      print('Error extracting description: $e');
      return 'Transaction';
    }
  }

  // Enhanced balance extraction
  String _extractBalance(String body) {
    try {
      final balancePatterns = [
        RegExp(
          r'BAL\s*RS\.?\s*(\d+(?:,\d{3})*(?:\.\d{1,2})?)',
          caseSensitive: false,
        ),
        RegExp(
          r'AVAILABLE\s*BALANCE\s*RS\.?\s*(\d+(?:,\d{3})*(?:\.\d{1,2})?)',
          caseSensitive: false,
        ),
        RegExp(
          r'CURRENT\s*BALANCE\s*RS\.?\s*(\d+(?:,\d{3})*(?:\.\d{1,2})?)',
          caseSensitive: false,
        ),
        RegExp(
          r'BALANCE\s*RS\.?\s*(\d+(?:,\d{3})*(?:\.\d{1,2})?)',
          caseSensitive: false,
        ),
      ];

      for (final pattern in balancePatterns) {
        final match = pattern.firstMatch(body);
        if (match != null) {
          return '₹${match.group(1)}';
        }
      }

      return 'N/A';
    } catch (e) {
      print('Error extracting balance: $e');
      return 'N/A';
    }
  }

  // Enhanced account number extraction
  String _extractAccountNumber(String body) {
    try {
      final patterns = [
        RegExp(r'A/C\s*NO[:\s]*(\d{4,})', caseSensitive: false),
        RegExp(r'CARD\s*NO[:\s]*(\d{4,})', caseSensitive: false),
        RegExp(r'ACCOUNT\s*NO[:\s]*(\d{4,})', caseSensitive: false),
        RegExp(r'ACCOUNT\s*NUMBER[:\s]*(\d{4,})', caseSensitive: false),
        RegExp(r'CARD\s*NUMBER[:\s]*(\d{4,})', caseSensitive: false),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(body);
        if (match != null) {
          return match.group(1) ?? '';
        }
      }

      return 'N/A';
    } catch (e) {
      print('Error extracting account number: $e');
      return 'N/A';
    }
  }

  // Extract reference number
  String _extractReferenceNumber(String body) {
    try {
      final patterns = [
        RegExp(r'REF\s*NO[:\s]*(\w+)', caseSensitive: false),
        RegExp(r'REFERENCE\s*NO[:\s]*(\w+)', caseSensitive: false),
        RegExp(r'TXN\s*ID[:\s]*(\w+)', caseSensitive: false),
        RegExp(r'TRANSACTION\s*ID[:\s]*(\w+)', caseSensitive: false),
        RegExp(r'UPI\s*REF[:\s]*(\w+)', caseSensitive: false),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(body);
        if (match != null) {
          return match.group(1) ?? '';
        }
      }

      return 'N/A';
    } catch (e) {
      print('Error extracting reference number: $e');
      return 'N/A';
    }
  }

  // Test method to check SMS fetching
  Future<void> testSMSScanning() async {
    try {
      print('🧪 Testing SMS scanning...');

      // Check permission
      final hasPermission = await hasSMSPermission();
      print('📱 SMS Permission: ${hasPermission ? "✅ Granted" : "❌ Denied"}');

      if (!hasPermission) {
        print('🔐 Requesting SMS permission...');
        final granted = await requestSMSPermission();
        print(
          '📱 Permission request result: ${granted ? "✅ Granted" : "❌ Denied"}',
        );

        if (!granted) {
          print('❌ Cannot proceed without SMS permission');
          return;
        }
      }

      // Try to fetch SMS
      print('📨 Attempting to fetch SMS messages...');
      final messages = await getRecentSMS(limit: 10);
      print('📊 Successfully fetched ${messages.length} SMS messages');

      if (messages.isNotEmpty) {
        print('📧 Sample messages:');
        for (int i = 0; i < (messages.length > 3 ? 3 : messages.length); i++) {
          final msg = messages[i];
          print('  ${i + 1}. From: ${msg.address}');
          print(
            '     Body: ${msg.body?.substring(0, (msg.body?.length ?? 0) > 100 ? 100 : msg.body?.length ?? 0)}...',
          );
          print('     Date: ${msg.date}');
          print('');
        }
      } else {
        print(
          '⚠️ No SMS messages found. Make sure you have SMS messages in your inbox.',
        );
      }
    } catch (e) {
      print('❌ Test failed: $e');
    }
  }

  // Get recent transaction SMS messages with enhanced filtering
  Future<List<TransactionSMS>> getRecentTransactions({int limit = 50}) async {
    try {
      print('🚀 Starting transaction scan...');

      final messages = await getRecentSMS(limit: limit);
      final bankMessages = filterBankSMS(messages);

      print('💳 Parsing ${bankMessages.length} bank messages...');
      final transactions = <TransactionSMS>[];

      for (int i = 0; i < bankMessages.length; i++) {
        final message = bankMessages[i];
        print(
          '📝 Parsing message ${i + 1}/${bankMessages.length}: ${message.address}',
        );

        final transaction = parseTransactionSMS(message);
        if (transaction != null) {
          print(
            '✅ Parsed transaction: ${transaction.bankName} - ₹${transaction.amount} (${transaction.transactionType})',
          );
          transactions.add(transaction);
        } else {
          print('❌ Failed to parse transaction from: ${message.address}');
        }
      }

      // Sort by date (most recent first)
      transactions.sort((a, b) => b.date.compareTo(a.date));

      print(
        '🎉 Scan complete! Found ${transactions.length} valid transactions',
      );
      return transactions;
    } catch (e) {
      print('❌ Error getting recent transactions: $e');
      throw Exception('Failed to get recent transactions: $e');
    }
  }

  // Get transactions by date range
  Future<List<TransactionSMS>> getTransactionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 100,
  }) async {
    try {
      final messages = await getRecentSMS(limit: limit);
      final bankMessages = filterBankSMS(messages);

      final transactions = <TransactionSMS>[];

      for (final message in bankMessages) {
        final transaction = parseTransactionSMS(message);
        if (transaction != null) {
          final transactionDate = transaction.date;
          if (transactionDate.isAfter(
                startDate.subtract(const Duration(days: 1)),
              ) &&
              transactionDate.isBefore(endDate.add(const Duration(days: 1)))) {
            transactions.add(transaction);
          }
        }
      }

      // Sort by date (most recent first)
      transactions.sort((a, b) => b.date.compareTo(a.date));

      return transactions;
    } catch (e) {
      print('Error getting transactions by date range: $e');
      throw Exception('Failed to get transactions by date range: $e');
    }
  }

  // Get transactions by bank
  Future<List<TransactionSMS>> getTransactionsByBank({
    required String bankName,
    int limit = 50,
  }) async {
    try {
      final transactions = await getRecentTransactions(limit: limit);
      return transactions
          .where(
            (transaction) => transaction.bankName.toLowerCase().contains(
              bankName.toLowerCase(),
            ),
          )
          .toList();
    } catch (e) {
      print('Error getting transactions by bank: $e');
      throw Exception('Failed to get transactions by bank: $e');
    }
  }

  // Get transaction statistics
  Future<Map<String, dynamic>> getTransactionStatistics({
    int limit = 100,
  }) async {
    try {
      final transactions = await getRecentTransactions(limit: limit);

      if (transactions.isEmpty) {
        return {
          'totalTransactions': 0,
          'totalDebit': 0.0,
          'totalCredit': 0.0,
          'bankBreakdown': <String, int>{},
          'categoryBreakdown': <String, double>{},
        };
      }

      double totalDebit = 0.0;
      double totalCredit = 0.0;
      final bankBreakdown = <String, int>{};
      final categoryBreakdown = <String, double>{};

      for (final transaction in transactions) {
        // Bank breakdown
        bankBreakdown[transaction.bankName] =
            (bankBreakdown[transaction.bankName] ?? 0) + 1;

        // Amount breakdown
        if (transaction.transactionType == 'debit') {
          totalDebit += transaction.amount;
        } else {
          totalCredit += transaction.amount;
        }

        // Category breakdown (simplified)
        final category = _categorizeTransaction(transaction.description);
        categoryBreakdown[category] =
            (categoryBreakdown[category] ?? 0.0) + transaction.amount;
      }

      return {
        'totalTransactions': transactions.length,
        'totalDebit': totalDebit,
        'totalCredit': totalCredit,
        'bankBreakdown': bankBreakdown,
        'categoryBreakdown': categoryBreakdown,
      };
    } catch (e) {
      print('Error getting transaction statistics: $e');
      throw Exception('Failed to get transaction statistics: $e');
    }
  }

  // Simple transaction categorization
  String _categorizeTransaction(String description) {
    final desc = description.toLowerCase();

    if (desc.contains('swiggy') ||
        desc.contains('zomato') ||
        desc.contains('restaurant') ||
        desc.contains('food') ||
        desc.contains('cafe') ||
        desc.contains('bigbasket') ||
        desc.contains('groceries')) {
      return 'Food';
    } else if (desc.contains('fuel') ||
        desc.contains('petrol') ||
        desc.contains('diesel') ||
        desc.contains('ola') ||
        desc.contains('uber') ||
        desc.contains('travel') ||
        desc.contains('bus') ||
        desc.contains('train')) {
      return 'Transportation';
    } else if (desc.contains('movie') ||
        desc.contains('cinema') ||
        desc.contains('entertainment') ||
        desc.contains('netflix') ||
        desc.contains('spotify')) {
      return 'Entertainment';
    } else if (desc.contains('amazon') ||
        desc.contains('flipkart') ||
        desc.contains('shop') ||
        desc.contains('purchase') ||
        desc.contains('myntra')) {
      return 'Shopping';
    } else if (desc.contains('bill') ||
        desc.contains('electricity') ||
        desc.contains('rent') ||
        desc.contains('utility') ||
        desc.contains('internet')) {
      return 'Bills';
    } else if (desc.contains('hospital') ||
        desc.contains('pharmacy') ||
        desc.contains('doctor') ||
        desc.contains('medical')) {
      return 'Healthcare';
    } else if (desc.contains('school') ||
        desc.contains('college') ||
        desc.contains('education') ||
        desc.contains('course')) {
      return 'Education';
    }

    return 'Other';
  }
}
