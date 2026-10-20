import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/models/pending_transaction.dart';
import '../utils/transaction_identity.dart';

class PendingTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Candidate search window; identity checks also require matching direction
  /// and reference, or merchant within two minutes.
  static const Duration _dedupWindow = Duration(hours: 24);

  // Add a pending transaction
  Future<bool> addPendingTransaction(PendingTransaction transaction) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User not authenticated');

    // Skip if this transaction looks like one the user already saved.
    if (await _isAlreadySaved(user.uid, transaction)) {
      debugPrint(
        'PendingTransactionService: skipped — duplicate of saved expense '
        '(amount=${transaction.amount}, merchant=${transaction.merchantName})',
      );
      return false;
    }

    final pending = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('pending_transactions');
    final candidates = await pending
        .where('detectedAt',
            isGreaterThanOrEqualTo:
                transaction.detectedAt.subtract(_dedupWindow).toIso8601String())
        .where('detectedAt',
            isLessThanOrEqualTo:
                transaction.detectedAt.add(_dedupWindow).toIso8601String())
        .get();
    for (final doc in candidates.docs) {
      final other = PendingTransaction.fromMap(doc.data());
      // A replay must continue to auto-save if a previous save failed.
      if (other.id == transaction.id) return true;
      if (TransactionIdentity.matches(
        amount: transaction.amount,
        type: transaction.transactionType,
        date: transaction.detectedAt,
        merchant: transaction.merchantName,
        text: transaction.rawNotificationText,
        otherAmount: other.amount,
        otherType: other.transactionType,
        otherDate: other.detectedAt,
        otherMerchant: other.merchantName,
        otherText: other.rawNotificationText,
      )) {
        return false;
      }
    }

    if (_auth.currentUser?.uid != user.uid) {
      throw StateError('Account changed during detection');
    }
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('pending_transactions')
        .doc(transaction.id)
        .set(transaction.toMap());
    return true;
  }

  Future<bool> _isAlreadySaved(
    String uid,
    PendingTransaction transaction,
  ) async {
    try {
      final expenses =
          _firestore.collection('users').doc(uid).collection('expenses');
      if ((await expenses.doc(transaction.id).get()).exists) return true;
      final start = transaction.detectedAt.subtract(_dedupWindow);
      final end = transaction.detectedAt.add(_dedupWindow);

      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      return snapshot.docs.any((doc) {
        final expense = Expense.fromJson(doc.data());
        return TransactionIdentity.matches(
          amount: transaction.amount,
          type: transaction.transactionType,
          date: transaction.detectedAt,
          merchant: transaction.merchantName,
          text: transaction.rawNotificationText,
          otherAmount: expense.amount,
          otherType:
              expense.type == TransactionType.income ? 'credit' : 'debit',
          otherDate: expense.date,
          otherMerchant: expense.title,
          otherText: expense.description,
        );
      });
    } catch (e) {
      // Retain the native queue for retry rather than risk an auto-save duplicate.
      debugPrint('PendingTransactionService: dedup lookup failed: $e');
      rethrow;
    }
  }

  // Get all pending transactions
  Stream<List<PendingTransaction>> getPendingTransactions() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('pending_transactions')
        .orderBy('detectedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PendingTransaction.fromMap(doc.data()))
          .toList();
    }).handleError((Object error, StackTrace stackTrace) {
      // Don't let Firestore connectivity blips kill the stream — the UI keeps
      // its last value and can show a non-fatal error. Subscribers that care
      // about errors specifically can still attach their own onError handler.
    });
  }

  /// Fetches a single pending transaction by id. Returns null if it's
  /// already been confirmed/rejected (or the user signed out).
  Future<PendingTransaction?> getPendingById(String id) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pending_transactions')
          .doc(id)
          .get();
      if (!doc.exists) return null;
      return PendingTransaction.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('getPendingById failed: $e');
      return null;
    }
  }

  /// One-shot confirm flow used by the notification "Confirm" action:
  /// converts the pending row to an [Expense], saves it, deletes the
  /// pending doc, and returns the saved expense. Returns null if the
  /// pending doc was already gone (idempotent — safe to retry).
  Future<Expense?> confirmPending(String id) async {
    final uid = _auth.currentUser?.uid;
    final pending = await getPendingById(id);
    if (pending == null) return null;
    if (uid == null || _auth.currentUser?.uid != uid) {
      throw StateError('Account changed during confirmation');
    }

    final expense = Expense(
      id: pending.id,
      title: pending.merchantName,
      amount: pending.amount,
      date: pending.detectedAt,
      category: pending.suggestedCategory ??
          (pending.isCredit ? 'Income' : 'Digital Payments'),
      description:
          'Auto-detected from ${pending.appName}\n${pending.rawNotificationText}',
      type: pending.isCredit ? TransactionType.income : TransactionType.expense,
    );

    final user = _auth.currentUser;
    if (user == null) throw StateError('User not authenticated');
    final root = _firestore.collection('users').doc(user.uid);
    final batch = _firestore.batch();
    batch.set(root.collection('expenses').doc(expense.id), {
      ...expense.toJson(),
      'userId': user.uid,
    });
    batch.delete(root.collection('pending_transactions').doc(pending.id));
    await batch.commit();
    return expense;
  }

  // Delete a pending transaction (reject)
  Future<void> deletePendingTransaction(String transactionId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('pending_transactions')
        .doc(transactionId)
        .delete();
  }

  // Get count of pending transactions
  Stream<int> getPendingTransactionCount() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('pending_transactions')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
