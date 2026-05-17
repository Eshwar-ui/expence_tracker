import 'package:expence_tracker/utils/notification_parsing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationValidation', () {
    group('duplicateKey', () {
      test('produces stable key from timestamp, amount, and source', () {
        final key = NotificationValidation.duplicateKey(
          timestamp: 1700000000000,
          amount: 499,
          source: 'com.paytm',
        );
        expect(key, equals('1700000000000_499.00_com.paytm'));
      });

      test('normalizes source to lowercase', () {
        final key = NotificationValidation.duplicateKey(
          timestamp: 1,
          amount: 100,
          source: 'COM.BANK',
        );
        expect(key, equals('1_100.00_com.bank'));
      });
    });

    group('validate', () {
      test('returns invalid_amount when amount is null', () {
        final result = NotificationValidation.validate(
          const ParsingResult(
            amount: null,
            transactionType: 'debit',
            merchant: 'X',
            confidence: 0.9,
          ),
          timestamp: 1700000000000,
          source: 'com.bank',
        );
        expect(result.isValid, isFalse);
        expect(result.reasons, contains('invalid_amount'));
      });

      test('returns invalid_amount when amount is zero', () {
        final result = NotificationValidation.validate(
          const ParsingResult(
            amount: 0,
            transactionType: 'debit',
            merchant: 'X',
            confidence: 0.9,
          ),
          timestamp: 1700000000000,
          source: 'com.bank',
        );
        expect(result.isValid, isFalse);
        expect(result.reasons, contains('invalid_amount'));
      });

      test('returns low_confidence when confidence below threshold', () {
        final result = NotificationValidation.validate(
          const ParsingResult(
            amount: 120,
            transactionType: 'debit',
            merchant: 'Y',
            confidence: 0.4,
          ),
          timestamp: 1700000000000,
          source: 'com.bank',
        );
        expect(result.isValid, isFalse);
        expect(result.reasons, contains('low_confidence'));
      });

      test('returns invalid_timestamp when timestamp is 0', () {
        final result = NotificationValidation.validate(
          const ParsingResult(
            amount: 120,
            transactionType: 'debit',
            merchant: 'Y',
            confidence: 0.9,
          ),
          timestamp: 0,
          source: 'com.bank',
        );
        expect(result.isValid, isFalse);
        expect(result.reasons, contains('invalid_timestamp'));
      });

      test('returns duplicate when duplicateFound is true', () {
        final result = NotificationValidation.validate(
          const ParsingResult(
            amount: 120,
            transactionType: 'debit',
            merchant: 'Y',
            confidence: 0.9,
          ),
          timestamp: 1700000000000,
          source: 'com.bank',
          duplicateFound: true,
        );
        expect(result.isValid, isFalse);
        expect(result.reasons, contains('duplicate'));
      });

      test('returns valid when all inputs are valid', () {
        final result = NotificationValidation.validate(
          const ParsingResult(
            amount: 120,
            transactionType: 'debit',
            merchant: 'Y',
            confidence: 0.9,
          ),
          timestamp: 1700000000000,
          source: 'com.bank',
        );
        expect(result.isValid, isTrue);
        expect(result.reasons, isEmpty);
      });
    });
  });
}
