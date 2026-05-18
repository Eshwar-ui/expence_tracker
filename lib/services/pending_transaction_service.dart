import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:expence_tracker/models/pending_transaction.dart';

class PendingTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Window used to consider an existing expense as a duplicate of a freshly
  /// detected pending transaction. Same amount within ±24h is treated as the
  /// same txn (covers SMS/notification timing skew).
  static const Duration _dedupWindow = Duration(hours: 24);

  // Add a pending transaction
  Future<void> addPendingTransaction(PendingTransaction transaction) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Skip if this transaction looks like one the user already saved.
    if (await _isAlreadySaved(user.uid, transaction)) {
      debugPrint(
        'PendingTransactionService: skipped — duplicate of saved expense '
        '(amount=${transaction.amount}, merchant=${transaction.merchantName})',
      );
      return;
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('pending_transactions')
        .doc(transaction.id)
        .set(transaction.toMap());
  }

  Future<bool> _isAlreadySaved(
    String uid,
    PendingTransaction transaction,
  ) async {
    try {
      final start = transaction.detectedAt.subtract(_dedupWindow);
      final end = transaction.detectedAt.add(_dedupWindow);

      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .where('amount', isEqualTo: transaction.amount)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      // If the lookup fails (offline, missing index), don't block the inbox.
      debugPrint('PendingTransactionService: dedup lookup failed: $e');
      return false;
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
