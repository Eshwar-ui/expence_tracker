import 'package:another_telephony/telephony.dart';
import '../models/transaction_sms.dart';

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
    return false;
  }

  Future<bool> requestSMSPermission() async {
    return false;
  }

  Future<List<SmsMessage>> getAllSMS({int maxMessages = 1000}) async {
    return [];
  }

  Future<List<TransactionSMS>> getAllTransactions({int limit = 500}) async {
    return [];
  }

  Future<List<TransactionSMS>> getRecentTransactions({int limit = 50}) async {
    return [];
  }
}
