import 'package:expence_tracker/models/category.dart';
import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/screens/expense_dialog.dart';
import 'package:expence_tracker/services/category_service.dart';
import 'package:expence_tracker/services/firestore_service.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const String _rupee = '\u20B9';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final FirestoreService _firestore = FirestoreService();
  final CategoryService _categoryService = CategoryService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _loadError;
  List<Expense> _allTransactions = [];
  List<Expense> _displayTransactions = [];
  List<Category> _categories = [];

  String _searchQuery = '';
  String _activeFilter = 'All';
  String? _selectedCategory;
  DateTime? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
      });
    } catch (_) {
      // Categories are optional for browsing.
    }
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final items = await _firestore.getExpenses();
      if (!mounted) return;

      items.sort((a, b) => b.date.compareTo(a.date));
      _allTransactions = items;
      _applyFilters(notify: false);

      setState(() {
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Unable to load transactions right now.';
      });
      showDesignSystemSnackBar(
        context: context,
        message: "Couldn't load transactions. Pull to retry.",
        isError: true,
      );
    }
  }

  void _applyFilters({bool notify = true}) {
    final filtered = _allTransactions.where((expense) {
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          expense.title.toLowerCase().contains(query) ||
          expense.category.toLowerCase().contains(query) ||
          expense.description.toLowerCase().contains(query);

      final matchesType = _activeFilter == 'All' ||
          (_activeFilter == 'Income' &&
              expense.type == TransactionType.income) ||
          (_activeFilter == 'Expense' &&
              expense.type == TransactionType.expense);

      final matchesCategory =
          _selectedCategory == null || expense.category == _selectedCategory;

      final matchesMonth = _selectedMonth == null ||
          (expense.date.year == _selectedMonth!.year &&
              expense.date.month == _selectedMonth!.month);

      return matchesSearch && matchesType && matchesCategory && matchesMonth;
    }).toList();

    if (!mounted) return;

    if (notify) {
      setState(() {
        _displayTransactions = filtered;
      });
    } else {
      _displayTransactions = filtered;
    }
  }

  List<DateTime> _getAvailableMonths() {
    final uniqueMonths = <int, DateTime>{};
    for (final transaction in _allTransactions) {
      final month = DateTime(transaction.date.year, transaction.date.month);
      uniqueMonths[month.millisecondsSinceEpoch] = month;
    }

    final months = uniqueMonths.values.toList()..sort((a, b) => b.compareTo(a));
    return months;
  }

  Map<String, List<Expense>> _groupTransactions() {
    final groups = <String, List<Expense>>{};
    for (final transaction in _displayTransactions) {
      final monthKey = DateFormat('MMMM yyyy').format(transaction.date);
      groups.putIfAbsent(monthKey, () => []);
      groups[monthKey]!.add(transaction);
    }
    return groups;
  }

  int get _activeFilterCount {
    var count = 0;
    if (_activeFilter != 'All') count++;
    if (_selectedCategory != null) count++;
    if (_selectedMonth != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _groupTransactions();
    final months = grouped.keys.toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PremiumAppBar(
        title: 'Transactions',
        showBackButton: false,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(theme),
          _buildSummaryStrip(theme),
          Expanded(
            child: _loading
                ? const DesignSystemLoading()
                : _loadError != null
                    ? _buildErrorState()
                    : _displayTransactions.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDesignSystem.s24,
                            ),
                            physics: const BouncingScrollPhysics(),
                            itemCount: months.length,
                            itemBuilder: (context, index) {
                              final month = months[index];
                              final monthItems = grouped[month]!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildMonthHeader(theme, month, monthItems),
                                  ...monthItems.map(
                                    (expense) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppDesignSystem.s12,
                                      ),
                                      child: PremiumTransactionTile(
                                        title: expense.title,
                                        category: expense.category,
                                        amount: expense.amount,
                                        date: expense.date,
                                        isIncome:
                                            expense.type == TransactionType.income,
                                        onTap: () => _showTransactionDetails(
                                          context,
                                          expense,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (index == months.length - 1)
                                    const VSpace(120)
                                  else
                                    const VSpace.lg(),
                                ],
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => ExpenseDialog(onTransactionSaved: _load),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
    );
  }

  Widget _buildSearchAndFilter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDesignSystem.s24,
        AppDesignSystem.s8,
        AppDesignSystem.s24,
        AppDesignSystem.s16,
      ),
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: DesignSystemTextField(
              controller: _searchController,
              label: 'Search',
              hint: 'Search transactions...',
              icon: Icons.search_rounded,
              onChanged: (value) {
                _searchQuery = value;
                _applyFilters();
              },
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _searchQuery = '';
                        _applyFilters();
                      },
                    )
                  : null,
            ),
          ),
          const HSpace.md(),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: _activeFilterCount > 0
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _activeFilterCount > 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: IconButton(
                icon: Badge(
                  isLabelVisible: _activeFilterCount > 0,
                  label: Text('$_activeFilterCount'),
                  child: Icon(
                    Icons.tune_rounded,
                    color: _activeFilterCount > 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                onPressed: () => _showFilterBottomSheet(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(ThemeData theme) {
    final income = _displayTransactions
        .where((expense) => expense.type == TransactionType.income)
        .fold<double>(0, (sum, expense) => sum + expense.amount);
    final expenses = _displayTransactions
        .where((expense) => expense.type == TransactionType.expense)
        .fold<double>(0, (sum, expense) => sum + expense.amount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDesignSystem.s24,
        0,
        AppDesignSystem.s24,
        AppDesignSystem.s16,
      ),
      // IntrinsicHeight + stretch makes the three cards take the height of
      // the tallest one, even if helper lines wrap differently.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildSummaryCard(
                theme: theme,
                title: 'Showing',
                value: _displayTransactions.length.toString(),
                helper: _activeFilterCount == 0 ? 'All transactions' : 'Filtered',
                color: AppDesignSystem.brandPrimary,
              ),
            ),
            const HSpace.md(),
            Expanded(
              child: _buildSummaryCard(
                theme: theme,
                title: 'Income',
                value: '$_rupee${income.toStringAsFixed(0)}',
                helper: 'Visible results',
                color: AppDesignSystem.success,
              ),
            ),
            const HSpace.md(),
            Expanded(
              child: _buildSummaryCard(
                theme: theme,
                title: 'Spent',
                value: '$_rupee${expenses.toStringAsFixed(0)}',
                helper: 'Visible results',
                color: AppDesignSystem.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required ThemeData theme,
    required String title,
    required String value,
    required String helper,
    required Color color,
  }) {
    return DesignSystemCard(
      glass: true,
      padding: const EdgeInsets.all(AppDesignSystem.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodySmall),
          const VSpace.xs(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const VSpace.xs(),
          Text(helper, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    final availableMonths = _getAvailableMonths();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            return Container(
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight,
              ),
              child: DesignSystemCard(
                glass: true,
                padding: const EdgeInsets.all(AppDesignSystem.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const VSpace.lg(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter Transactions',
                          style: theme.textTheme.titleLarge,
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _activeFilter = 'All';
                              _selectedCategory = null;
                              _selectedMonth = null;
                            });
                            _applyFilters();
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const VSpace.lg(),
                    Text('Transaction Type', style: theme.textTheme.titleMedium),
                    const VSpace.sm(),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'All', label: Text('All')),
                        ButtonSegment(value: 'Income', label: Text('Income')),
                        ButtonSegment(value: 'Expense', label: Text('Expense')),
                      ],
                      selected: {_activeFilter},
                      onSelectionChanged: (selection) {
                        setModalState(() {
                          _activeFilter = selection.first;
                        });
                        _applyFilters();
                      },
                    ),
                    const VSpace.lg(),
                    Text('Month', style: theme.textTheme.titleMedium),
                    const VSpace.sm(),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<DateTime?>(
                          value: _selectedMonth,
                          isExpanded: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Months'),
                            ),
                            ...availableMonths.map(
                              (month) => DropdownMenuItem(
                                value: month,
                                child: Text(
                                  DateFormat('MMMM yyyy').format(month),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setModalState(() => _selectedMonth = value);
                            _applyFilters();
                          },
                        ),
                      ),
                    ),
                    const VSpace.lg(),
                    Text('Category', style: theme.textTheme.titleMedium),
                    const VSpace.sm(),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedCategory,
                          isExpanded: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Categories'),
                            ),
                            ..._categories.map(
                              (category) => DropdownMenuItem(
                                value: category.name,
                                child: Row(
                                  children: [
                                    Icon(
                                      category.icon,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(category.name),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setModalState(() => _selectedCategory = value);
                            _applyFilters();
                          },
                        ),
                      ),
                    ),
                    const VSpace.xl(),
                    GradientButton(
                      text: 'Done',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMonthHeader(
    ThemeData theme,
    String month,
    List<Expense> monthItems,
  ) {
    final monthTotal = monthItems.fold<double>(
      0,
      (sum, expense) => expense.type == TransactionType.income
          ? sum + expense.amount
          : sum - expense.amount,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.s16),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  month.split(' ').first,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const HSpace.sm(),
                Text(
                  month.split(' ').last,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${monthTotal >= 0 ? '+' : '-'}$_rupee${monthTotal.abs().toStringAsFixed(0)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: monthTotal >= 0
                  ? AppDesignSystem.success
                  : AppDesignSystem.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.s24),
      child: DesignSystemEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Transactions unavailable',
        message: _loadError,
        action: TextButton(
          onPressed: _load,
          child: const Text('Retry'),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters =
        _searchQuery.isNotEmpty || _activeFilterCount > 0;

    return DesignSystemEmptyState(
      icon: Icons.receipt_long_rounded,
      title: hasFilters ? 'No matching transactions' : 'No transactions yet',
      message: hasFilters
          ? 'Try clearing your search or filters to see more results.'
          : 'Your financial history will appear here once you start tracking.',
      action: hasFilters
          ? TextButton(
              onPressed: () {
                _searchController.clear();
                _searchQuery = '';
                _activeFilter = 'All';
                _selectedCategory = null;
                _selectedMonth = null;
                _applyFilters();
              },
              child: const Text('Clear filters'),
            )
          : null,
    );
  }

  void _showTransactionDetails(BuildContext context, Expense expense) {
    final theme = Theme.of(context);
    final isIncome = expense.type == TransactionType.income;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DesignSystemCard(
        glass: true,
        padding: const EdgeInsets.all(AppDesignSystem.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const VSpace.lg(),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDesignSystem.s16),
                  decoration: BoxDecoration(
                    color: (isIncome
                            ? AppDesignSystem.success
                            : AppDesignSystem.error)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDesignSystem.r16),
                  ),
                  child: Icon(
                    isIncome
                        ? Icons.keyboard_double_arrow_down_rounded
                        : Icons.keyboard_double_arrow_up_rounded,
                    color: isIncome
                        ? AppDesignSystem.success
                        : AppDesignSystem.error,
                  ),
                ),
                const HSpace.md(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(expense.title, style: theme.textTheme.headlineSmall),
                      Text(expense.category, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const VSpace.xl(),
            _buildDetailRow(
              context,
              'Amount',
              '$_rupee${expense.amount.toStringAsFixed(2)}',
              isIncome ? AppDesignSystem.success : AppDesignSystem.error,
            ),
            _buildDetailRow(
              context,
              'Date',
              DateFormat('EEEE, MMM dd, yyyy').format(expense.date),
              null,
            ),
            _buildDetailRow(
              context,
              'Time',
              DateFormat('hh:mm a').format(expense.date),
              null,
            ),
            if (expense.description.isNotEmpty)
              _buildDetailRow(context, 'Note', expense.description, null),
            const VSpace.xl(),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    text: 'Edit',
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => ExpenseDialog(
                          expense: expense,
                          onTransactionSaved: _load,
                        ),
                      );
                    },
                  ),
                ),
                const HSpace.md(),
                Expanded(
                  child: GradientButton(
                    text: 'Delete',
                    gradient: AppDesignSystem.errorGradient,
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation(context, expense);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    Color? valueColor,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignSystem.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Expense expense) {
    showDesignSystemDialog(
      context: context,
      title: 'Delete Transaction',
      message:
          'Are you sure you want to delete "${expense.title}"? This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      onConfirm: () async {
        try {
          await _firestore.deleteExpense(expense.id);
          await _load();
        } catch (_) {
          if (!context.mounted) return;
          showDesignSystemSnackBar(
            context: context,
            message: "Couldn't delete the transaction.",
            isError: true,
          );
        }
      },
    );
  }
}
