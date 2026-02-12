import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/models/notification_payload.dart';
import 'package:expence_tracker/services/firestore_service.dart';
import 'package:expence_tracker/services/notification_tracking_service.dart';
import 'package:expence_tracker/services/auto_tracking_settings_service.dart';
import 'package:expence_tracker/utils/notification_parsing.dart';

class AutoInsertResult {
  final bool success;
  final String? expenseId;
  final List<String> reasons;

  const AutoInsertResult({
    required this.success,
    required this.expenseId,
    required this.reasons,
  });
}

class AutoUndoResult {
  final bool success;
  final List<String> reasons;

  const AutoUndoResult({
    required this.success,
    required this.reasons,
  });
}

class NotificationAutoExpenseService {
  final FirestoreService _firestoreService;
  final NotificationTrackingService _trackingService;
  final AutoTrackingSettingsService _settingsService;

  NotificationAutoExpenseService({
    FirestoreService? firestoreService,
    NotificationTrackingService? trackingService,
    AutoTrackingSettingsService? settingsService,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _trackingService = trackingService ?? NotificationTrackingService(),
        _settingsService =
            settingsService ?? AutoTrackingSettingsService();

  Future<AutoInsertResult> processPayload(NotificationPayload payload) async {
    final parse = NotificationParsing.parse(
      payload.text,
      title: payload.title,
    );

    final source = payload.packageName;
    final timestamp = payload.timestamp;
    final amount = parse.amount;

    if (amount == null) {
      return const AutoInsertResult(
        success: false,
        expenseId: null,
        reasons: <String>['invalid_amount'],
      );
    }

    final duplicateKey = NotificationValidation.duplicateKey(
      timestamp: timestamp,
      amount: amount,
      source: source,
    );
    final isDuplicate = await _trackingService.isTransactionAdded(duplicateKey);

    final validation = NotificationValidation.validate(
      parse,
      timestamp: timestamp,
      source: source,
      amount: amount,
      duplicateFound: isDuplicate,
    );

    if (!validation.isValid) {
      if (validation.reasons.contains('low_confidence')) {
        await _settingsService.incrementNeedsReview();
      }
      return AutoInsertResult(
        success: false,
        expenseId: null,
        reasons: validation.reasons,
      );
    }

    final title = parse.merchant?.isNotEmpty == true
        ? parse.merchant!
        : (payload.title.isNotEmpty ? payload.title : 'Auto Transaction');

    final expense = Expense(
      id: timestamp.toString(),
      title: title,
      amount: amount,
      date: DateTime.fromMillisecondsSinceEpoch(timestamp),
      category: 'Other',
      description: 'Auto-tracked',
      type: parse.transactionType == 'credit'
          ? TransactionType.income
          : TransactionType.expense,
      paymentMethod: source,
    );

    try {
      await _firestoreService.addExpense(expense);
      try {
        await _trackingService.markTransactionAsAdded(duplicateKey);
        await _settingsService.setLastAutoInsert(expense.id, duplicateKey);
      } catch (e) {
        // Rollback if tracking fails after insert.
        await _firestoreService.deleteExpense(expense.id);
        return const AutoInsertResult(
          success: false,
          expenseId: null,
          reasons: <String>['tracking_failed_rollback'],
        );
      }

      return AutoInsertResult(
        success: true,
        expenseId: expense.id,
        reasons: const <String>[],
      );
    } catch (e) {
      return const AutoInsertResult(
        success: false,
        expenseId: null,
        reasons: <String>['insert_failed'],
      );
    }
  }

  Future<AutoUndoResult> undoLastAutoInsert() async {
    final expenseId = await _settingsService.getLastExpenseId();
    final duplicateKey = await _settingsService.getLastDuplicateKey();

    if (expenseId == null || duplicateKey == null) {
      return const AutoUndoResult(
        success: false,
        reasons: <String>['no_last_auto_insert'],
      );
    }

    try {
      await _firestoreService.deleteExpense(expenseId);
      await _trackingService.markTransactionAsNotAdded(duplicateKey);
      await _settingsService.clearLastAutoInsert();
      return const AutoUndoResult(success: true, reasons: <String>[]);
    } catch (e) {
      return const AutoUndoResult(
        success: false,
        reasons: <String>['undo_failed'],
      );
    }
  }
}
