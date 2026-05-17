import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/category.dart' as model;
import '../models/recurring_transaction.dart';
import '../services/category_service.dart';
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
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
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
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
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
  final CategoryService _categoryService = CategoryService();
  List<String> _categoryOptions = [];
  String? _category;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _titleCtrl.text = widget.transaction!.title;
      _amountCtrl.text = widget.transaction!.amount.toStringAsFixed(0);
      _freq = widget.transaction!.frequency;
      _category = widget.transaction!.category;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getCategories();
      final expenseCategories = categories
          .where((c) => c.type == model.CategoryType.expense)
          .map((c) => c.name)
          .toSet()
          .toList()
        ..sort();

      if (!mounted) return;
      setState(() {
        _categoryOptions = expenseCategories;
        if (_category == null && _categoryOptions.isNotEmpty) {
          _category = _categoryOptions.first;
        } else if (_category != null && !_categoryOptions.contains(_category)) {
          _categoryOptions = [..._categoryOptions, _category!];
        }
      });
    } catch (_) {
      if (!mounted) return;
      final fallback = RecurringTransactionService.getCommonCategories();
      setState(() {
        _categoryOptions = fallback;
        _category ??= fallback.first;
      });
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
            initialValue: _freq,
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
          const VSpace.md(),
          DropdownButtonFormField<String>(
            initialValue:
                _categoryOptions.contains(_category) ? _category : null,
            items: _categoryOptions
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(c),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _category = v),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const VSpace.xl(),
          if (widget.transaction != null) ...[
            OutlinedButton.icon(
              onPressed: _loading ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete Schedule'),
            ),
            const VSpace.md(),
          ],
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
    final title = _titleCtrl.text.trim();
    final amountText = _amountCtrl.text.trim();
    if (title.isEmpty) {
      showDesignSystemSnackBar(
        context: context,
        message: 'Give this schedule a title.',
        isError: true,
      );
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      showDesignSystemSnackBar(
        context: context,
        message: 'Enter an amount greater than zero.',
        isError: true,
      );
      return;
    }
    if (_category == null) {
      showDesignSystemSnackBar(
        context: context,
        message: 'Pick a category.',
        isError: true,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final t = RecurringTransaction(
        id: widget.transaction?.id ?? widget.service.generateId(),
        userId: FirebaseAuth.instance.currentUser!.uid,
        title: title,
        description: '',
        amount: amount,
        category: _category!,
        frequency: _freq,
        startDate: DateTime.now(),
        createdAt: widget.transaction?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      if (widget.transaction == null) {
        await widget.service.createRecurringTransaction(t);
      } else {
        await widget.service.updateRecurringTransaction(t);
      }
      widget.onSaved();
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _delete() async {
    final transaction = widget.transaction;
    if (transaction == null) return;

    await showDesignSystemDialog<void>(
      context: context,
      title: 'Delete recurring payment?',
      message:
          'This will permanently remove "${transaction.title}" from your recurring schedules.',
      confirmLabel: 'Delete',
      destructive: true,
      onConfirm: () async {
        if (!mounted) return;
        setState(() => _loading = true);
        try {
          await widget.service.deleteRecurringTransaction(transaction.id);
          widget.onSaved();
          if (mounted) Navigator.pop(context);
        } finally {
          if (mounted) {
            setState(() => _loading = false);
          }
        }
      },
    );
  }
}
