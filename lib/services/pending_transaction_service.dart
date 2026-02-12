import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expence_tracker/models/pending_transaction.dart';

class PendingTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add a pending transaction
  Future<void> addPendingTransaction(PendingTransaction transaction) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('pending_transactions')
        .doc(transaction.id)
        .set(transaction.toMap());
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
