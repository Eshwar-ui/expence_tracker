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
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final SMSService _smsService = SMSService();
  final SMSTrackingService _trackingService = SMSTrackingService();

  List<TransactionSMS> _transactions = [];
  Set<String> _addedTransactions = {};
  Set<String> _selectedTransactions = {}; // For bulk selection
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

  Future<void> _loadAddedTransactions() async {
    try {
      final addedTransactions = await _trackingService.getAddedTransactionIds();
      if (!mounted) return;
      setState(() {
        _addedTransactions = addedTransactions;
      });
    } catch (e) {
      print('Failed to load added transactions: $e');
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to scan transactions: $e';
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

      // Get all SMS messages (this will show progress)
      final transactions = await _smsService.getAllTransactions();
      if (!mounted) return;

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${transactions.length} transactions'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to scan transactions: $e';
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppDesignSystem.error,
          duration: const Duration(seconds: 3),
        ),
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

      for (final transactionId in _selectedTransactions) {
        final transaction = _transactions.firstWhere(
          (t) => t.id == transactionId,
        );

        try {
          final expense = Expense(
            id:
                DateTime.now().millisecondsSinceEpoch.toString() +
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
        } catch (e) {
          print('Error adding transaction ${transaction.id}: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _selectedTransactions.clear();
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $successCount transaction(s) successfully!'),
          backgroundColor: AppDesignSystem.brandSecondary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppDesignSystem.error,
        ),
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
          } catch (e) {
            print('Failed to mark transaction as added: $e');
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
      filtered = filtered
          .where((t) => _addedTransactions.contains(t.id))
          .toList();
    } else if (_filterType == 'not_added') {
      filtered = filtered
          .where((t) => !_addedTransactions.contains(t.id))
          .toList();
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
              color: theme.colorScheme.primary.withOpacity(0.1),
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
      body: Column(
        children: [
          _buildTopSearchAndFilter(theme),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _selectedTransactions.isNotEmpty
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
          : null,
    );
  }

  Widget _buildTopSearchAndFilter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: Column(
        children: [
          DesignSystemTextField(
            controller: TextEditingController(text: _searchQuery)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: _searchQuery.length),
              ),
            label: 'Search',
            hint: 'Search merchant or bank...',
            icon: Icons.search_rounded,
            onChanged: (val) => setState(() => _searchQuery = val),
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                color: AppDesignSystem.brandPrimary.withOpacity(0.1),
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
                    '${_transactions.length} Transactions Detected',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${_addedTransactions.length} already in your records',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _checkPermissionAndScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 64, color: Colors.orange[300]),
            const SizedBox(height: 16),
            Text(
              'Permission Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We need SMS permission to scan your transaction messages. This helps automatically detect your expenses.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _checkPermissionAndScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Grant Permission',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sms_failed, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Transactions Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We couldn\'t find any recent transaction messages in your SMS. Make sure you have received bank alerts recently.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _scanAllTransactions,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignSystem.brandPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Scan Again',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
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
                        .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDebit
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: isDebit
                    ? AppDesignSystem.error
                    : AppDesignSystem.success,
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
                          ? theme.colorScheme.onSurface.withOpacity(0.4)
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${transaction.bankName} • ${DateFormat('MMM dd').format(transaction.date)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isDebit ? '-' : '+'}₹${transaction.amount.toStringAsFixed(0)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isAdded
                        ? theme.colorScheme.onSurface.withOpacity(0.3)
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
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.1,
                        ),
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
        selectedColor: theme.colorScheme.primary.withOpacity(0.15),
        labelStyle: TextStyle(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withOpacity(0.6),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.r12),
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
    );
  }
}
