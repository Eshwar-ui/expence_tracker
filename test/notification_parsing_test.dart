import 'package:flutter_test/flutter_test.dart';
import 'package:expence_tracker/utils/transaction_parser.dart';

// Mock NotificationEvent since we can't import the real one easily without plugins
class MockNotificationEvent {
  final String packageName;
  final String title;
  final String text;

  MockNotificationEvent({
    required this.packageName,
    required this.title,
    required this.text,
  });
}

void main() {
  group('Notification Listener Feature Tests', () {
    test('Should detect payment apps correctly', () {
      final paymentApps = [
        'com.google.android.apps.nbu.paisa.user',
        'com.phonepe.app',
        'net.one97.paytm',
        'in.org.npci.upiapp',
        'com.sbi.upi',
      ];

      final incomingPackage = 'com.google.android.apps.nbu.paisa.user';
      expect(paymentApps.contains(incomingPackage), isTrue);

      final nonPaymentPackage = 'com.whatsapp';
      expect(paymentApps.contains(nonPaymentPackage), isFalse);
    });

    test('Should extract amount from GPay notification text', () {
      final notificationText = 'Paid ₹500 to Swiggy';
      final amount = TransactionParser.extractAmount(notificationText);
      expect(amount, equals(500.0));
    });

    test('Should extract amount from PhonePe notification text', () {
      final notificationText = 'Paid Rs. 1,250.50 to Zomato for food';
      final amount = TransactionParser.extractAmount(notificationText);
      expect(amount, equals(1250.50));
    });

    test('Should extract amount from Paytm notification text', () {
      final notificationText = 'Sent Rs 2000 to John Doe';
      final amount = TransactionParser.extractAmount(notificationText);
      expect(amount, equals(2000.0));
    });

    test('Should ignore non-transaction notifications', () {
      final notificationText = 'You have a new message from Swiggy';
      final amount = TransactionParser.extractAmount(notificationText);
      expect(amount, isNull);
    });

    test('Should normalize merchant names from notification body', () {
      final body = 'Paid ₹350 to Swiggy via UPI';
      final merchant = TransactionParser.normalizeDescription(body);
      expect(merchant, equals('Swiggy'));

      final body2 = 'Paid ₹999 to Netflix Entertainment';
      final merchant2 = TransactionParser.normalizeDescription(body2);
      expect(merchant2, equals('Netflix'));
    });

    test('Should suggest correct category based on merchant', () {
      final merchant = 'Swiggy';
      final category = TransactionParser.suggestCategory(merchant);
      expect(category, equals('Food'));

      final merchant2 = 'Uber';
      final category2 = TransactionParser.suggestCategory(merchant2);
      expect(category2, equals('Transportation'));
    });
  });
}
