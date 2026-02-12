import 'package:flutter/material.dart';
import 'package:expence_tracker/models/pending_transaction.dart';
import 'package:expence_tracker/services/pending_transaction_service.dart';
import 'package:expence_tracker/services/firestore_service.dart';
import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:intl/intl.dart';

class PendingTransactionsScreen extends StatelessWidget {
  const PendingTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppDesignSystem.darkBg,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.darkBg,
        title: const Text('Review Transactions'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<PendingTransaction>>(
        stream: PendingTransactionService().getPendingTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final transactions = snapshot.data ?? [];

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  const VSpace.lg(),
                  Text(
                    'All caught up!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const VSpace.sm(),
                  Text(
                    'No pending transactions to review',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return _PendingTransactionCard(
                transaction: transaction,
                onApprove: () => _approveTransaction(context, transaction),
                onReject: () => _rejectTransaction(context, transaction),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _approveTransaction(
      BuildContext context, PendingTransaction transaction) async {
    try {
      // Create expense from pending transaction
      final expense = Expense(
        id: transaction.id,
        title: transaction.merchantName,
        amount: transaction.amount,
        date: transaction.detectedAt,
        category: transaction.suggestedCategory ?? 'Digital Payments',
        description:
            'Auto-detected from ${transaction.appName}\\n${transaction.rawNotificationText}',
        type: TransactionType.expense,
      );

      // Add expense to Firestore
      await FirestoreService().addExpense(expense);

      // Delete pending transaction
      await PendingTransactionService()
          .deletePendingTransaction(transaction.id);

      if (context.mounted) {
        showDesignSystemSnackBar(
          context: context,
          message: 'Transaction approved: ₹${transaction.amount}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showDesignSystemSnackBar(
          context: context,
          message: 'Failed to approve: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _rejectTransaction(
      BuildContext context, PendingTransaction transaction) async {
    try {
      await PendingTransactionService()
          .deletePendingTransaction(transaction.id);

      if (context.mounted) {
        showDesignSystemSnackBar(
          context: context,
          message: 'Transaction rejected',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showDesignSystemSnackBar(
          context: context,
          message: 'Failed to reject: $e',
          isError: true,
        );
      }
    }
  }
}

class _PendingTransactionCard extends StatelessWidget {
  final PendingTransaction transaction;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingTransactionCard({
    required this.transaction,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeAgo = _getTimeAgo(transaction.detectedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppDesignSystem.darkCanvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppDesignSystem.brandPrimary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: App name and time
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.brandPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    transaction.appName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppDesignSystem.brandPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  timeAgo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            const VSpace.md(),

            // Amount
            Row(
              children: [
                Text(
                  '₹${transaction.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (transaction.suggestedCategory != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.brandSecondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      transaction.suggestedCategory!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppDesignSystem.brandSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const VSpace.sm(),

            // Merchant
            Text(
              transaction.merchantName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const VSpace.sm(),

            // Raw notification text (truncated)
            Text(
              transaction.rawNotificationText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const VSpace.lg(),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const HSpace.md(),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.brandPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }
}
