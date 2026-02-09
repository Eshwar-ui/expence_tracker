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
    if (!await hasSMSPermission())
      throw Exception('SMS permission not granted');

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
      final sender = m.address ?? '';
      final body = m.body ?? '';
      final isBank = TransactionParser.bankPatterns.keys
          .any((bank) => sender.toUpperCase().contains(bank));
      final hasKeywords = TransactionParser.transactionKeywords
          .any((key) => body.toUpperCase().contains(key));
      return isBank || hasKeywords;
    }).toList();

    return bankMessages
        .map((m) => _parse(m))
        .whereType<TransactionSMS>()
        .toList();
  }

  TransactionSMS? _parse(SmsMessage message) {
    final body = message.body ?? '';
    final sender = message.address ?? '';
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
    final match = RegExp(r'A/C\s*NO[:\s]*(\d{4,})', caseSensitive: false)
        .firstMatch(body);
    return match?.group(1) ?? 'N/A';
  }

  String _extractBalance(String body) {
    final match = RegExp(r'BAL\s*RS\.?\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)',
            caseSensitive: false)
        .firstMatch(body);
    return match != null ? '₹${match.group(1)}' : 'N/A';
  }
}
