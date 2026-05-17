import 'package:flutter/material.dart';
import 'package:expence_tracker/models/transaction_sms.dart';
import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/services/sms_service.dart';
import 'package:expence_tracker/services/sms_tracking_service.dart';
import 'package:expence_tracker/services/firestore_service.dart';

import 'package:expence_tracker/screens/expense_dialog.dart';
import 'package:intl/intl.dart';
import '../utils/app_design_system.dart';
import '../widgets/design_system_components.dart';

class ScanScreen extends StatefulWidget {
  final bool showScaffold;

  const ScanScreen({
    super.key,
    this.showScaffold = true,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final SMSService _smsService = SMSService();
  final SMSTrackingService _trackingService = SMSTrackingService();
  final TextEditingController _searchController = TextEditingController();

  List<TransactionSMS> _transactions = [];
  Set<String> _addedTransactions = {};
  final Set<String> _selectedTransactions = {}; // For bulk selection
  bool _isLoading = false;
  bool _hasPermission = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'debit', 'credit', 'added', 'not_added'

  @override
  void initState() {
    super.initState();
    _loadAddedTransactions();
    _checkPermissionAndScan();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAddedTransactions() async {
    try {
      final addedTransactions = await _trackingService.getAddedTransactionIds();
      if (!mounted) return;
      setState(() {
        _addedTransactions = addedTransactions;
      });
    } catch (_) {
      // Non-fatal: empty added-set just means we won't grey-out already-added rows.
    }
  }

  Future<void> _checkPermissionAndScan() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Check permission first
      final hasPermission = await _smsService.hasSMSPermission();
      if (!mounted) return;

      if (!hasPermission) {
        final granted = await _smsService.requestSMSPermission();
        if (!mounted) return;

        if (!granted) {
          setState(() {
            _isLoading = false;
            _hasPermission = false;
            _errorMessage = 'SMS permission is required to scan transactions';
          });
          return;
        }
      }

      setState(() => _hasPermission = true);

      // Now scan all SMS messages
      await _scanAllTransactions();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Couldn't scan SMS. Please try again.";
      });
    }
  }

  Future<void> _scanAllTransactions() async {
    try {
      // Show progress indicator
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final transactions = await _smsService.getAllTransactions();

      if (!mounted) return;

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });

      // Show success message
      if (mounted) {
        showDesignSystemSnackBar(
          context: context,
          message: 'Found ${transactions.length} transactions',
          icon: Icons.sms_rounded,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Couldn't scan SMS. Please try again.";
      });

      showDesignSystemSnackBar(
        context: context,
        message: "Couldn't scan SMS. Please try again.",
        isError: true,
      );
    }
  }

  // Bulk add selected transactions
  Future<void> _bulkAddTransactions() async {
    if (_selectedTransactions.isEmpty) return;

    try {
      setState(() => _isLoading = true);
      final firestoreService = FirestoreService();
      int successCount = 0;

      int failureCount = 0;
      for (final transactionId in _selectedTransactions) {
        TransactionSMS? transaction;
        for (final t in _transactions) {
          if (t.id == transactionId) {
            transaction = t;
            break;
          }
        }
        if (transaction == null) {
          failureCount++;
          continue;
        }

        try {
          final expense = Expense(
            id: DateTime.now().millisecondsSinceEpoch.toString() +
                transactionId,
            title: transaction.description,
            amount: transaction.amount,
            date: transaction.date,
            category: _getCategoryFromDescription(transaction.description),
            description: 'Auto-detected from SMS: ${transaction.bankName}',
            type: transaction.transactionType.toLowerCase() == 'credit'
                ? TransactionType.income
                : TransactionType.expense,
            paymentMethod: 'Bank Transfer',
          );

          await firestoreService.addExpense(expense);
          await _trackingService.markTransactionAsAdded(transaction.id);
          _addedTransactions.add(transaction.id);
          successCount++;
        } catch (_) {
          failureCount++;
        }
      }

      if (!mounted) return;
      setState(() {
        _selectedTransactions.clear();
        _isLoading = false;
      });

      final summary = failureCount == 0
          ? 'Added $successCount transaction(s) successfully!'
          : 'Added $successCount, skipped $failureCount that failed.';
      showDesignSystemSnackBar(
        context: context,
        message: summary,
        icon: failureCount == 0
            ? Icons.done_all_rounded
            : Icons.warning_amber_rounded,
        isError: successCount == 0,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showDesignSystemSnackBar(
        context: context,
        message: "Couldn't add transactions. Please try again.",
        isError: true,
      );
    }
  }

  // Get category from description
  String _getCategoryFromDescription(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('food') ||
        desc.contains('restaurant') ||
        desc.contains('grocery')) {
      return 'Food';
    } else if (desc.contains('fuel') ||
        desc.contains('petrol') ||
        desc.contains('transport')) {
      return 'Transportation';
    } else if (desc.contains('movie') ||
        desc.contains('entertainment') ||
        desc.contains('netflix')) {
      return 'Entertainment';
    } else if (desc.contains('shopping') ||
        desc.contains('amazon') ||
        desc.contains('flipkart')) {
      return 'Shopping';
    } else if (desc.contains('bill') ||
        desc.contains('electricity') ||
        desc.contains('water')) {
      return 'Bills';
    } else if (desc.contains('medical') ||
        desc.contains('hospital') ||
        desc.contains('pharmacy')) {
      return 'Healthcare';
    } else if (desc.contains('education') ||
        desc.contains('school') ||
        desc.contains('book')) {
      return 'Education';
    } else if (desc.contains('salary') || desc.contains('income')) {
      return 'Salary';
    }
    return 'Other';
  }

  void _showEditTransactionDialog(TransactionSMS transaction) {
    debugPrint('Opening edit dialog for: ${transaction.description}');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpenseDialog(
        smsTransaction: transaction,
        onTransactionSaved: () async {
          try {
            await _trackingService.markTransactionAsAdded(transaction.id);
            if (!mounted) return;
            setState(() {
              _addedTransactions.add(transaction.id);
              _selectedTransactions.remove(transaction.id);
            });
          } catch (_) {
            // Non-fatal: tracking lookup may be temporarily unavailable.
          }
        },
      ),
    );
  }

  // Get filtered transactions
  List<TransactionSMS> get _filteredTransactions {
    var filtered = _transactions;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        return t.description.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
            t.bankName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply type filter
    if (_filterType == 'debit') {
      filtered = filtered.where((t) => t.transactionType == 'debit').toList();
    } else if (_filterType == 'credit') {
      filtered = filtered.where((t) => t.transactionType == 'credit').toList();
    } else if (_filterType == 'added') {
      filtered =
          filtered.where((t) => _addedTransactions.contains(t.id)).toList();
    } else if (_filterType == 'not_added') {
      filtered =
          filtered.where((t) => !_addedTransactions.contains(t.id)).toList();
    }

    return filtered;
  }

  Map<String, List<TransactionSMS>> _groupTransactionsByMonth(
    List<TransactionSMS> transactions,
  ) {
    final Map<String, List<TransactionSMS>> groups = {};
    for (var t in transactions) {
      final monthKey = DateFormat('MMMM yyyy').format(t.date);
      if (groups[monthKey] == null) groups[monthKey] = [];
      groups[monthKey]!.add(t);
    }
    return groups;
  }

  Widget _buildMonthHeader(ThemeData theme, String month) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              month,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(
            child: Divider(indent: 12, endIndent: 0, thickness: 1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Column(
        children: [
          _buildTopSearchAndFilter(theme),
          Expanded(child: _buildBody()),
        ],
      );

    final fab = _selectedTransactions.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 90),
              child: FloatingActionButton.extended(
                onPressed: _bulkAddTransactions,
                backgroundColor: AppDesignSystem.brandPrimary,
                icon: const Icon(Icons.add_task_rounded, color: Colors.white),
                label: Text(
                  'Add ${_selectedTransactions.length} Selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : null;

    if (!widget.showScaffold) {
      return Stack(
        children: [
          body,
          if (fab != null)
            Positioned(
              right: 16,
              bottom: 16,
              child: fab,
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PremiumAppBar(
        title: 'Scan Transactions',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _scanAllTransactions,
            tooltip: 'Rescan all messages',
          ),
        ],
      ),
      body: body,
      floatingActionButton: fab,
    );
  }

  Widget _buildTopSearchAndFilter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: Column(
        children: [
          DesignSystemTextField(
            controller: _searchController,
            label: 'Search',
            hint: 'Search merchant or bank...',
            icon: Icons.search_rounded,
            onChanged: (val) => setState(() => _searchQuery = val),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
          const VSpace.md(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _filterType == 'all',
                  onSelected: () => setState(() => _filterType = 'all'),
                ),
                _FilterChip(
                  label: 'Debit',
                  isSelected: _filterType == 'debit',
                  onSelected: () => setState(() => _filterType = 'debit'),
                ),
                _FilterChip(
                  label: 'Credit',
                  isSelected: _filterType == 'credit',
                  onSelected: () => setState(() => _filterType = 'credit'),
                ),
                _FilterChip(
                  label: 'Not Added',
                  isSelected: _filterType == 'not_added',
                  onSelected: () => setState(() => _filterType = 'not_added'),
                ),
                _FilterChip(
                  label: 'Added',
                  isSelected: _filterType == 'added',
                  onSelected: () => setState(() => _filterType = 'added'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DesignSystemLoading(),
            const VSpace.md(),
            Text(
              'Scanning your inbox...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) return _buildErrorState();
    if (!_hasPermission) return _buildPermissionState();
    if (_transactions.isEmpty) return _buildEmptyState();

    final filtered = _filteredTransactions;
    if (filtered.isEmpty) {
      return const DesignSystemEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No Matches',
        message: 'No transactions found for the selected filters.',
      );
    }

    final grouped = _groupTransactionsByMonth(filtered);
    final months = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: months.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildSummaryCard();

        final month = months[index - 1];
        final monthItems = grouped[month]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonthHeader(Theme.of(context), month),
            ...monthItems.map((t) => _buildTransactionCard(t)),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: DesignSystemCard(
        glass: true,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppDesignSystem.brandPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppDesignSystem.brandPrimary,
                size: 24,
              ),
            ),
            const HSpace.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_transactions.length} Transactions Found',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${_addedTransactions.length} already marked as added',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DesignSystemEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Inbox scan failed',
          message: _errorMessage!,
          action: GradientButton(
            text: 'Try Again',
            onPressed: _checkPermissionAndScan,
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DesignSystemEmptyState(
          icon: Icons.security_rounded,
          title: 'SMS permission required',
          message:
              'Allow SMS access to detect bank transaction messages and prepare them for review.',
          action: GradientButton(
            text: 'Grant Permission',
            onPressed: _checkPermissionAndScan,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DesignSystemEmptyState(
          icon: Icons.sms_failed_rounded,
          title: 'No transactions found',
          message:
              'We could not find recent bank transaction messages in your SMS inbox.',
          action: GradientButton(
            text: 'Scan Again',
            onPressed: _scanAllTransactions,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(TransactionSMS transaction) {
    final theme = Theme.of(context);
    final isAdded = _addedTransactions.contains(transaction.id);
    final isDebit = transaction.transactionType == 'debit';
    final isSelected = _selectedTransactions.contains(transaction.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DesignSystemCard(
        onTap: isAdded
            ? null
            : () {
                setState(() {
                  if (isSelected) {
                    _selectedTransactions.remove(transaction.id);
                  } else {
                    _selectedTransactions.add(transaction.id);
                  }
                });
              },
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (!isAdded)
              Checkbox(
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedTransactions.add(transaction.id);
                    } else {
                      _selectedTransactions.remove(transaction.id);
                    }
                  });
                },
                activeColor: AppDesignSystem.brandPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (isDebit ? AppDesignSystem.error : AppDesignSystem.success)
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDebit
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color:
                    isDebit ? AppDesignSystem.error : AppDesignSystem.success,
                size: 20,
              ),
            ),
            const HSpace.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: isAdded ? TextDecoration.lineThrough : null,
                      color: isAdded
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${transaction.bankName} | ${DateFormat('MMM dd').format(transaction.date)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isDebit ? '-' : '+'}\u20B9${transaction.amount.toStringAsFixed(0)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isAdded
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                        : (isDebit
                            ? AppDesignSystem.error
                            : AppDesignSystem.success),
                  ),
                ),
                if (isAdded)
                  const DesignSystemBadge(
                    text: 'Added',
                    color: AppDesignSystem.success,
                  )
                else
                  GestureDetector(
                    onTap: () {}, // Stop propagation
                    child: TextButton(
                      onPressed: () => _showEditTransactionDialog(transaction),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Edit',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        backgroundColor: theme.colorScheme.surface,
        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.r12),
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
    );
  }
}
