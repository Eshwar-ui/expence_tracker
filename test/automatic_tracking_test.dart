import 'package:expence_tracker/utils/notification_parsing.dart';
import 'package:expence_tracker/utils/transaction_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Transaction intake regressions', () {
    test('bank route prefix does not reject a completed payment', () {
      for (final sender in ['AD-HDFCBK', 'VM-ICICIB', 'AX-SBIINB']) {
        expect(
            RejectionRules.rejectionReason(
              'Rs. 250 debited from A/c XX1234 to SWIGGY. Avl bal Rs. 5000',
              sender: sender,
            ),
            isNull);
      }
    });

    test('failed, pending and requested payments are not expenses', () {
      for (final text in [
        'Payment of Rs 500 to Swiggy failed',
        'Rs 500 payment pending to Swiggy',
        'Payment request of Rs 500 from Ramesh',
        'Rs 500 sent to Ramesh was declined',
      ]) {
        expect(RejectionRules.rejectionReason(text), 'incomplete_payment');
      }
    });

    test('short keywords do not match inside merchant names', () {
      final parsed = NotificationParsing.parse('Sent Rs 500 to Microsoft');
      expect(parsed.transactionType, 'debit');
      expect(parsed.amount, 500);
      expect(parsed.merchant, 'Microsoft');
    });

    test('Indian digit grouping does not truncate the amount', () {
      expect(NotificationParsing.parse('Rs 1,25,000 credited from ACME').amount,
          125000);
    });

    test('balance before payment is not chosen as the expense', () {
      expect(
          NotificationParsing.parse('Avl bal Rs 5,000. Paid Rs 200 to Swiggy')
              .amount,
          200);
    });

    test('credit card purchase stays a debit', () {
      final parsed =
          NotificationParsing.parse('Paid Rs 300 to Swiggy using credit card');
      expect(parsed.transactionType, 'debit');
    });

    test('completed payment without merchant remains reviewable', () {
      final parsed =
          NotificationParsing.parse('Rs 300 debited from A/c XX1234');
      expect(parsed.transactionType, 'debit');
      expect(parsed.confidence, greaterThanOrEqualTo(0.75));
      expect(parsed.confidence, lessThan(0.9));
    });
  });

  group('Independent transaction reports', () {
    final date = DateTime(2026, 10, 19, 12);
    bool matches(
            {String type = 'debit',
            String text = '',
            String otherText = '',
            String otherMerchant = 'Swiggy',
            Duration delay = Duration.zero}) =>
        TransactionIdentity.matches(
          amount: 250,
          type: 'debit',
          date: date,
          merchant: 'Swiggy',
          text: text,
          otherAmount: 250,
          otherType: type,
          otherDate: date.add(delay),
          otherMerchant: otherMerchant,
          otherText: otherText,
        );

    test('same amount alone cannot hide other purchases or income', () {
      expect(matches(otherMerchant: 'Uber'), isFalse);
      expect(matches(type: 'credit'), isFalse);
      expect(matches(delay: const Duration(hours: 4)), isFalse);
    });

    test('SMS and UPI reports with same reference match', () {
      expect(
          matches(
              text: 'UPI Ref: 123456789012',
              otherText: 'UTR 123456789012',
              otherMerchant: 'SWIGGY Bengaluru',
              delay: const Duration(minutes: 10)),
          isTrue);
    });

    test('different references preserve repeated equal payments', () {
      expect(matches(text: 'Ref 123456789012', otherText: 'Ref 123456789013'),
          isFalse);
    });
  });
}
