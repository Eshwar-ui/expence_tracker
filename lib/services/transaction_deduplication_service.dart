import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/models/transaction_sms.dart';
import 'package:expence_tracker/services/firestore_service.dart';

/// Service to handle deduplication of SMS transactions against manual entries.
///
/// Matching criteria:
/// - Amount matches within a small floating-point tolerance
/// - Date is within the same calendar day
/// - Transaction type matches (credit -> income, debit -> expense)
class TransactionDeduplicationService {
  final FirestoreService _firestoreService = FirestoreService();

  // SMS parsers and bank rounding can disagree by up to ~0.5 rupees in the
  // fee/charge variants. A tight 0.01 tolerance missed real duplicates;
  // widening to 0.50 catches them while still avoiding false matches between
  // distinct same-day amounts (which are typically >1 rupee apart).
  static const double _amountTolerance = 0.50;

  /// Check if a single SMS transaction already exists as a manual entry.
  /// Issues a one-day Firestore query. Prefer [filterOutDuplicates] when
  /// processing batches — it issues a single range query for all of them.
  Future<Expense?> findDuplicateManualEntry(
      TransactionSMS smsTransaction) async {
    try {
      final startOfDay = DateTime(
        smsTransaction.date.year,
        smsTransaction.date.month,
        smsTransaction.date.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final expenses = await _firestoreService.getExpensesByDateRange(
        startOfDay,
        endOfDay,
      );

      return _findMatchInMemory(smsTransaction, expenses);
    } catch (_) {
      return null;
    }
  }

  /// Filter out SMS transactions that already exist as manual entries.
  ///
  /// Uses a single Firestore range query covering the span of all SMS dates,
  /// then deduplicates in memory. This avoids the previous N-queries-per-batch
  /// pattern (50 SMS x 50 days could trigger ~2500 reads).
  Future<List<TransactionSMS>> filterOutDuplicates(
    List<TransactionSMS> smsTransactions,
  ) async {
    if (smsTransactions.isEmpty) return const [];

    final range = _spanOfDays(smsTransactions);
    List<Expense> candidateExpenses;
    try {
      candidateExpenses = await _firestoreService.getExpensesByDateRange(
        range.start,
        range.end,
      );
    } catch (_) {
      candidateExpenses = const [];
    }

    // Index candidates by yyyy-mm-dd for O(1) day lookup.
    final byDay = <String, List<Expense>>{};
    for (final expense in candidateExpenses) {
      byDay.putIfAbsent(_dayKey(expense.date), () => []).add(expense);
    }

    final uniqueTransactions = <TransactionSMS>[];
    for (final sms in smsTransactions) {
      final sameDay = byDay[_dayKey(sms.date)] ?? const [];
      final match = _findMatchInMemory(sms, sameDay);
      if (match == null) uniqueTransactions.add(sms);
    }

    return uniqueTransactions;
  }

  /// Returns true if a matching manual entry exists.
  /// Convenience wrapper; uses a per-transaction Firestore query.
  Future<bool> isDuplicate(TransactionSMS smsTransaction) async {
    return await findDuplicateManualEntry(smsTransaction) != null;
  }

  /// Get statistics about potential duplicates in a batch.
  /// Uses the batched range query like [filterOutDuplicates].
  Future<Map<String, dynamic>> getDuplicationStats(
    List<TransactionSMS> smsTransactions,
  ) async {
    final total = smsTransactions.length;
    if (total == 0) {
      return {
        'total': 0,
        'duplicates': 0,
        'unique': 0,
        'duplicationRate': '0.0',
      };
    }

    final unique = await filterOutDuplicates(smsTransactions);
    final duplicates = total - unique.length;

    return {
      'total': total,
      'duplicates': duplicates,
      'unique': unique.length,
      'duplicationRate': (duplicates / total * 100).toStringAsFixed(1),
    };
  }

  Expense? _findMatchInMemory(TransactionSMS sms, List<Expense> candidates) {
    final expectedType = sms.transactionType == 'credit'
        ? TransactionType.income
        : TransactionType.expense;

    for (final expense in candidates) {
      if (expense.type != expectedType) continue;
      if ((expense.amount - sms.amount).abs() >= _amountTolerance) continue;
      if (expense.date.year != sms.date.year) continue;
      if (expense.date.month != sms.date.month) continue;
      if (expense.date.day != sms.date.day) continue;
      return expense;
    }
    return null;
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  _DateRange _spanOfDays(List<TransactionSMS> txs) {
    DateTime min = txs.first.date;
    DateTime max = txs.first.date;
    for (final tx in txs) {
      if (tx.date.isBefore(min)) min = tx.date;
      if (tx.date.isAfter(max)) max = tx.date;
    }
    final start = DateTime(min.year, min.month, min.day);
    final end = DateTime(max.year, max.month, max.day)
        .add(const Duration(days: 1));
    return _DateRange(start, end);
  }
}

class _DateRange {
  final DateTime start;
  final DateTime end;
  const _DateRange(this.start, this.end);
}
