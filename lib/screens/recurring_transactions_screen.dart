import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recurring_transaction.dart';
import '../services/recurring_transaction_service.dart';
import '../utils/app_design_system.dart';
import '../widgets/design_system_components.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  final RecurringTransactionService _service = RecurringTransactionService();
  List<RecurringTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final transactions = await _service.getRecurringTransactions();
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Payments'),
        actions: [
          IconButton(
            onPressed: _loadTransactions,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const DesignSystemLoading()
          : _transactions.isEmpty
          ? _buildEmptyState()
          : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransactionDialog,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return DesignSystemEmptyState(
      icon: Icons.repeat_rounded,
      title: 'No Active Subscriptions',
      message: 'Track recurring bills like Netflix, Rent, or SIPs.',
      action: GradientButton(
        text: 'Add Recurring Bill',
        onPressed: _showAddTransactionDialog,
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDesignSystem.s24),
        physics: const BouncingScrollPhysics(),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final t = _transactions[index];
          final next = t.getNextExecutionDate();
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDesignSystem.s16),
            child: DesignSystemCard(
              onTap: () => _showEditTransactionDialog(t),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      DesignSystemBadge(
                        text: t.frequencyText,
                        color: AppDesignSystem.brandPrimary,
                      ),
                    ],
                  ),
                  const VSpace.sm(),
                  Row(
                    children: [
                      Text(
                        '₹${t.amount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: AppDesignSystem.brandPrimary),
                      ),
                      const HSpace.sm(),
                      Text(
                        '• ${t.category}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const VSpace.md(),
                  Row(
                    children: [
                      Icon(
                        Icons.event_repeat_rounded,
                        size: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const HSpace.sm(),
                      Text(
                        next != null
                            ? 'Next payment: ${DateFormat('MMM dd').format(next)}'
                            : 'Completed',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      if (t.shouldExecuteToday())
                        const DesignSystemBadge(
                          text: 'DUE TODAY',
                          color: AppDesignSystem.warning,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddTransactionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _RecurringDialog(service: _service, onSaved: _loadTransactions),
    );
  }

  void _showEditTransactionDialog(RecurringTransaction t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecurringDialog(
        service: _service,
        transaction: t,
        onSaved: _loadTransactions,
      ),
    );
  }
}

class _RecurringDialog extends StatefulWidget {
  final RecurringTransactionService service;
  final RecurringTransaction? transaction;
  final VoidCallback onSaved;
  const _RecurringDialog({
    required this.service,
    this.transaction,
    required this.onSaved,
  });
  @override
  State<_RecurringDialog> createState() => _RecurringDialogState();
}

class _RecurringDialogState extends State<_RecurringDialog> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  RecurringFrequency _freq = RecurringFrequency.monthly;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _titleCtrl.text = widget.transaction!.title;
      _amountCtrl.text = widget.transaction!.amount.toStringAsFixed(0);
      _freq = widget.transaction!.frequency;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesignSystemCard(
      glass: true,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.transaction == null ? 'New Schedule' : 'Edit Schedule',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const VSpace.xl(),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const VSpace.md(),
          TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(labelText: 'Amount (₹)'),
            keyboardType: TextInputType.number,
          ),
          const VSpace.md(),
          DropdownButtonFormField<RecurringFrequency>(
            value: _freq,
            items: RecurringFrequency.values
                .map(
                  (f) => DropdownMenuItem(
                    value: f,
                    child: Text(f.name.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _freq = v!),
            decoration: const InputDecoration(labelText: 'Frequency'),
          ),
          const VSpace.xl(),
          GradientButton(
            text: widget.transaction == null
                ? 'Create Schedule'
                : 'Update Schedule',
            isLoading: _loading,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty || _amountCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final t = RecurringTransaction(
        id: widget.transaction?.id ?? widget.service.generateId(),
        userId: FirebaseAuth.instance.currentUser!.uid,
        title: _titleCtrl.text,
        description: '',
        amount: double.parse(_amountCtrl.text),
        category: 'Billing',
        frequency: _freq,
        startDate: DateTime.now(),
        createdAt: widget.transaction?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      if (widget.transaction == null)
        await widget.service.createRecurringTransaction(t);
      else
        await widget.service.updateRecurringTransaction(t);
      widget.onSaved();
      Navigator.pop(context);
    } finally {
      setState(() => _loading = false);
    }
  }
}
