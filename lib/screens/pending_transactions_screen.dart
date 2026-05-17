import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/models/pending_transaction.dart';
import 'package:expence_tracker/services/firestore_service.dart';
import 'package:expence_tracker/services/pending_transaction_service.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const String _rupee = '\u20B9';

class PendingTransactionsScreen extends StatefulWidget {
  final bool showScaffold;

  const PendingTransactionsScreen({
    super.key,
    this.showScaffold = true,
  });

  @override
  State<PendingTransactionsScreen> createState() =>
      _PendingTransactionsScreenState();
}

class _PendingTransactionsScreenState extends State<PendingTransactionsScreen> {
  late Stream<List<PendingTransaction>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = PendingTransactionService().getPendingTransactions();
  }

  void _retry() {
    setState(() {
      _stream = PendingTransactionService().getPendingTransactions();
    });
  }

  bool get showScaffold => widget.showScaffold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = StreamBuilder<List<PendingTransaction>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: DesignSystemLoading());
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(AppDesignSystem.s24),
            child: DesignSystemEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Pending review unavailable',
              message: 'We could not load detected transactions right now.',
              action: TextButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ),
          );
        }

        final transactions = snapshot.data ?? [];

        if (transactions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppDesignSystem.s24),
            child: DesignSystemEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'All caught up',
              message: 'No pending transactions need review right now.',
            ),
          );
        }

        final creditCount = transactions.where((item) => item.isCredit).length;
        final debitCount = transactions.length - creditCount;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppDesignSystem.s24,
            AppDesignSystem.s8,
            AppDesignSystem.s24,
            120,
          ),
          itemCount: transactions.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDesignSystem.s16),
                child: _InboxSummaryCard(
                  totalCount: transactions.length,
                  debitCount: debitCount,
                  creditCount: creditCount,
                ),
              );
            }

            final transaction = transactions[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
              child: _PendingTransactionCard(
                transaction: transaction,
                onApprove: () => _approveTransaction(context, transaction),
                onReject: () => _rejectTransaction(context, transaction),
              ),
            );
          },
        );
      },
    );

    if (!showScaffold) {
      return body;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const PremiumAppBar(
        title: 'Review Transactions',
        centerTitle: true,
      ),
      body: body,
    );
  }

  Future<void> _approveTransaction(
    BuildContext context,
    PendingTransaction transaction,
  ) async {
    try {
      final transactionType =
          transaction.isCredit ? TransactionType.income : TransactionType.expense;
      final category = transaction.suggestedCategory ??
          (transaction.isCredit ? 'Income' : 'Digital Payments');

      final expense = Expense(
        id: transaction.id,
        title: transaction.merchantName,
        amount: transaction.amount,
        date: transaction.detectedAt,
        category: category,
        description:
            'Auto-detected from ${transaction.appName}\n${transaction.rawNotificationText}',
        type: transactionType,
      );

      await FirestoreService().addExpense(expense);
      await PendingTransactionService().deletePendingTransaction(transaction.id);

      if (context.mounted) {
        showDesignSystemSnackBar(
          context: context,
          message:
              '${transaction.isCredit ? 'Income' : 'Expense'} approved: $_rupee${transaction.amount.toStringAsFixed(2)}',
        );
      }
    } catch (error) {
      if (context.mounted) {
        showDesignSystemSnackBar(
          context: context,
          message: 'Failed to approve: $error',
          isError: true,
        );
      }
    }
  }

  Future<void> _rejectTransaction(
    BuildContext context,
    PendingTransaction transaction,
  ) async {
    try {
      await PendingTransactionService().deletePendingTransaction(transaction.id);

      if (context.mounted) {
        showDesignSystemSnackBar(
          context: context,
          message: 'Transaction rejected',
        );
      }
    } catch (error) {
      if (context.mounted) {
        showDesignSystemSnackBar(
          context: context,
          message: 'Failed to reject: $error',
          isError: true,
        );
      }
    }
  }
}

class _InboxSummaryCard extends StatelessWidget {
  final int totalCount;
  final int debitCount;
  final int creditCount;

  const _InboxSummaryCard({
    required this.totalCount,
    required this.debitCount,
    required this.creditCount,
  });

  @override
  Widget build(BuildContext context) {
    return DesignSystemCard(
      glass: true,
      padding: const EdgeInsets.all(AppDesignSystem.s20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.s12),
            decoration: BoxDecoration(
              color: AppDesignSystem.brandPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDesignSystem.r16),
            ),
            child: const Icon(
              Icons.inbox_rounded,
              color: AppDesignSystem.brandPrimary,
            ),
          ),
          const HSpace.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalCount items need review',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const VSpace.xs(),
                Text(
                  '$debitCount outgoing and $creditCount incoming detections are waiting.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    final accentColor =
        transaction.isCredit ? AppDesignSystem.success : AppDesignSystem.brandPrimary;
    final typeLabel = transaction.isCredit ? 'Incoming' : 'Outgoing';
    final approveLabel = transaction.isCredit ? 'Save Income' : 'Save Expense';
    final approveIcon =
        transaction.isCredit ? Icons.south_west_rounded : Icons.check_rounded;

    return DesignSystemCard(
      glass: true,
      padding: const EdgeInsets.all(AppDesignSystem.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  transaction.appName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const HSpace.sm(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(timeAgo, style: theme.textTheme.bodySmall),
            ],
          ),
          const VSpace.md(),
          Row(
            children: [
              Text(
                '${transaction.isCredit ? '+' : '-'}$_rupee${transaction.amount.toStringAsFixed(2)}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (transaction.suggestedCategory != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    transaction.suggestedCategory!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const VSpace.sm(),
          Text(
            transaction.merchantName,
            style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if ((transaction.description ?? '').isNotEmpty) ...[
            const VSpace.xs(),
            Text(
              transaction.description!,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const VSpace.sm(),
          Text(
            transaction.rawNotificationText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const VSpace.lg(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppDesignSystem.error,
                    side: const BorderSide(color: AppDesignSystem.error),
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
                  icon: Icon(approveIcon),
                  label: Text(approveLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
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
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    return DateFormat('MMM d, h:mm a').format(dateTime);
  }
}
