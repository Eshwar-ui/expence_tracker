import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction_sms.dart';
import '../utils/transaction_parser.dart';

class SMSService {
  // Use patterns from TransactionParser
  final List<RegExp> datePatterns = [
    RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{4})'),
    RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})'),
    RegExp(
        r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})',
        caseSensitive: false),
    RegExp(
        r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2}),?\s+(\d{4})',
        caseSensitive: false),
  ];

  Future<bool> hasSMSPermission() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  Future<bool> requestSMSPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<List<SmsMessage>> getAllSMS({int maxMessages = 1000}) async {
    // Auto-request once so callers don't have to. If still denied, return an
    // empty list rather than throwing — the UI surfaces "no transactions"
    // instead of a crash banner.
    if (!await hasSMSPermission()) {
      final granted = await requestSMSPermission();
      if (!granted) return const [];
    }

    final Telephony telephony = Telephony.instance;
    final List<SmsMessage> messages = await telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
    return messages.take(maxMessages).toList();
  }

  Future<List<TransactionSMS>> getAllTransactions({int limit = 500}) async {
    return getRecentTransactions(limit: limit);
  }

  Future<List<TransactionSMS>> getRecentTransactions({int limit = 50}) async {
    final messages = await getAllSMS(maxMessages: limit * 5);
    final bankMessages = messages.where((m) {
      final sender = TransactionParser.normalizeText(m.address ?? '');
      final body = TransactionParser.normalizeText(m.body ?? '');
      return TransactionParser.isBankMessage(sender, body);
    }).toList();

    return bankMessages
        .map((m) => _parse(m))
        .whereType<TransactionSMS>()
        .toList();
  }

  TransactionSMS? _parse(SmsMessage message) {
    final body = TransactionParser.normalizeText(message.body ?? '');
    final sender = TransactionParser.normalizeText(message.address ?? '');
    final amount = TransactionParser.extractAmount(body);

    if (amount == null) return null;

    return TransactionSMS(
      id: 'sms_${message.date}_$sender',
      bankName: TransactionParser.extractBankName(sender, body),
      accountNumber: _extractAccountNumber(body),
      transactionType: TransactionParser.extractTransactionType(body),
      amount: amount,
      date: message.date != null
          ? DateTime.fromMillisecondsSinceEpoch(message.date!)
          : DateTime.now(),
      description: TransactionParser.extractDescription(body),
      balance: _extractBalance(body),
      originalMessage: body,
      sender: sender,
      isAddedToExpenses: false,
    );
  }

  String _extractAccountNumber(String body) {
    // Looks for 'A/C', 'Acct', 'Account', 'Card', followed by optional text, then extracts the digits (usually masked with X or *).
    final match = RegExp(
            r'(?:A/C|ACCT|ACCOUNT|CARD|VPA)\s*(?:NO|ENDING|ENDING WITH)?\s*[:\-\*xX\s]*(\d{2,})',
            caseSensitive: false)
        .firstMatch(body);

    if (match != null) {
      return match.group(1) ?? 'N/A';
    }

    // Try a simpler match if the first one fails (e.g. *1703)
    final simpleMatch = RegExp(r'(?:\*|X{2,})([\d]{2,})', caseSensitive: false)
        .firstMatch(body);
    return simpleMatch?.group(1) ?? 'N/A';
  }

  String _extractBalance(String body) {
    final match = RegExp(r'BAL\s*RS\.?\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)',
            caseSensitive: false)
        .firstMatch(body);
    return match != null ? '₹${match.group(1)}' : 'N/A';
  }
}
