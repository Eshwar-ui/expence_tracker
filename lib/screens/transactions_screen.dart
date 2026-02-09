import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/models/category.dart';
import 'package:expence_tracker/services/firestore_service.dart';
import 'package:expence_tracker/services/category_service.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:expence_tracker/screens/expense_dialog.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final FirestoreService _firestore = FirestoreService();
  final CategoryService _categoryService = CategoryService();
  bool _loading = true;
  List<Expense> _allTransactions = [];
  List<Expense> _displayTransactions = [];
  List<Category> _categories = [];

  String _searchQuery = "";
  String _activeFilter = "All"; // All, Income, Expense
  String? _selectedCategory; // null means "All Categories"
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('Failed to load categories: $e');
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final items = await _firestore.getExpenses();
      if (!mounted) return;
      items.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _allTransactions = items;
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showDesignSystemSnackBar(
        context: context,
        message: 'Failed to load: $e',
        isError: true,
      );
    }
  }

  void _applyFilters() {
    setState(() {
      _displayTransactions = _allTransactions.where((e) {
        final matchesSearch =
            e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.category.toLowerCase().contains(_searchQuery.toLowerCase());

        bool matchesType = true;
        if (_activeFilter == "Income") {
          matchesType = e.type == TransactionType.income;
        } else if (_activeFilter == "Expense") {
          matchesType = e.type == TransactionType.expense;
        }

        bool matchesCategory = true;
        if (_selectedCategory != null) {
          matchesCategory = e.category == _selectedCategory;
        }

        return matchesSearch && matchesType && matchesCategory;
      }).toList();
    });
  }

  Map<String, List<Expense>> _groupTransactions() {
    final Map<String, List<Expense>> groups = {};
    for (var e in _displayTransactions) {
      final monthKey = DateFormat('MMMM yyyy').format(e.date);
      if (groups[monthKey] == null) groups[monthKey] = [];
      groups[monthKey]!.add(e);
    }
    return groups;
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
            onPressed: () => Navigator.pushNamed(context, '/scan'),
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/scan'),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(theme),
          Expanded(
            child: _loading
                ? const DesignSystemLoading()
                : _displayTransactions.isEmpty
                    ? _empty()
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
                              _buildMonthHeader(theme, month),
                              ...monthItems.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppDesignSystem.s12,
                                  ),
                                  child: PremiumTransactionTile(
                                    title: e.title,
                                    category: e.category,
                                    amount: e.amount,
                                    date: e.date,
                                    isIncome: e.type == TransactionType.income,
                                    onTap: () =>
                                        _showTransactionDetails(context, e),
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
      child: Column(
        children: [
          // Search Input
          DesignSystemTextField(
            controller: _searchController,
            label: 'Search',
            hint: 'Search transactions...',
            icon: Icons.search_rounded,
            onChanged: (val) {
              _searchQuery = val;
              _applyFilters();
            },
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _searchQuery = "";
                      _applyFilters();
                    },
                  )
                : null,
          ),
          const VSpace.md(),
          // Type Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ["All", "Income", "Expense"].map((filter) {
                final isActive = _activeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isActive,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _activeFilter = filter);
                        _applyFilters();
                      }
                    },
                    backgroundColor: theme.colorScheme.surface,
                    selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Category Filter Chips
          if (_categories.isNotEmpty) const VSpace.sm(),
          if (_categories.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // "All Categories" chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All Categories'),
                      selected: _selectedCategory == null,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = null);
                          _applyFilters();
                        }
                      },
                      backgroundColor: theme.colorScheme.surface,
                      selectedColor:
                          theme.colorScheme.secondary.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: _selectedCategory == null
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.onSurface,
                        fontWeight: _selectedCategory == null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: _selectedCategory == null
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                  ),
                  // Category chips
                  ..._categories.map((category) {
                    final isActive = _selectedCategory == category.name;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              category.icon,
                              size: 16,
                              color: isActive
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.onSurface,
                            ),
                            const SizedBox(width: 4),
                            Text(category.name),
                          ],
                        ),
                        selected: isActive,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = category.name);
                            _applyFilters();
                          }
                        },
                        backgroundColor: theme.colorScheme.surface,
                        selectedColor:
                            theme.colorScheme.secondary.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isActive
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.onSurface,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isActive
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(ThemeData theme, String month) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.s16),
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
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
          const HSpace.md(),
          Expanded(
            child: Container(
              height: 1,
              color: theme.colorScheme.onSurface.withOpacity(0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return const DesignSystemEmptyState(
      icon: Icons.receipt_long_rounded,
      title: 'No transactions yet',
      message:
          'Your financial history will appear here once you start tracking.',
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
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
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
                        .withOpacity(0.1),
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
              '₹${expense.amount.toStringAsFixed(2)}',
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
              color: theme.colorScheme.onSurface.withOpacity(0.5),
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
        await _firestore.deleteExpense(expense.id);
        _load();
      },
    );
  }
}
