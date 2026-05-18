import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction_sms.dart';
import '../models/expence.dart';
import '../models/category.dart' as model;
import '../services/firestore_service.dart';
import '../services/category_service.dart';
import '../services/reminder_service.dart';
import '../utils/app_design_system.dart';
import '../widgets/design_system_components.dart';
import '../utils/transaction_parser.dart';
import '../models/recurring_transaction.dart';
import '../services/recurring_transaction_service.dart';

class ExpenseDialog extends StatefulWidget {
  final TransactionSMS? smsTransaction;
  final Expense? expense;
  final VoidCallback onTransactionSaved;

  const ExpenseDialog({
    super.key,
    this.smsTransaction,
    this.expense,
    required this.onTransactionSaved,
  });

  @override
  State<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<ExpenseDialog>
    with TickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final CategoryService _categoryService = CategoryService();
  final FirestoreService _firestoreService = FirestoreService();
  final RecurringTransactionService _recurringService =
      RecurringTransactionService();

  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _categoriesLoading = true;
  List<model.Category> _categories = [];
  List<RecurringTransaction> _recurringOptions = [];

  // Keypad state
  String _amountString = '0';

  late AnimationController _typeToggleController;
  late AnimationController _amountBounceController;
  late Animation<double> _amountBounce;

  @override
  void initState() {
    super.initState();
    _typeToggleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _amountBounceController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
      value: 1.0,
    );
    _amountBounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _amountBounceController,
      curve: Curves.easeInOut,
    ));

    _loadCategories();
    _loadRecurringOptions();
    _initializeFields();
  }

  Future<void> _loadRecurringOptions() async {
    try {
      final options = await _recurringService.getRecurringTransactions();
      if (mounted) setState(() => _recurringOptions = options);
    } catch (e) {
      debugPrint('Failed to load recurring options: $e');
    }
  }

  Future<void> _loadCategories() async {
    final cats = await _categoryService.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _categoriesLoading = false;
      _ensureValidCategory();
    });
  }

  void _ensureValidCategory() {
    if (_categories.isEmpty) return;
    final typeName = _selectedType == TransactionType.income
        ? model.CategoryType.income.name
        : model.CategoryType.expense.name;
    final filtered = _categories.where((c) => c.type.name == typeName).toList();
    if (_selectedCategory == null ||
        !filtered.any((c) => c.name == _selectedCategory)) {
      if (filtered.isNotEmpty) _selectedCategory = filtered.first.name;
    }
  }

  void _onTypeChanged(TransactionType type) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedType = type;
      _ensureValidCategory();
    });
    if (type == TransactionType.income) {
      _typeToggleController.forward();
    } else {
      _typeToggleController.reverse();
    }
    _loadCategories();
  }

  void _initializeFields() {
    if (widget.expense != null) {
      final e = widget.expense!;
      _titleController.text = e.title;
      _amountString = e.amount == e.amount.truncateToDouble()
          ? e.amount.toStringAsFixed(0)
          : e.amount.toStringAsFixed(2);
      _descriptionController.text = e.description;
      _selectedType = e.type;
      _selectedCategory = e.category;
      _selectedDate = e.date;
      if (_selectedType == TransactionType.income) {
        _typeToggleController.value = 1.0;
      }
    } else if (widget.smsTransaction != null) {
      final sms = widget.smsTransaction!;
      final raw = sms.description.isNotEmpty ? sms.description : sms.originalMessage;
      _titleController.text = TransactionParser.normalizeDescription(raw);
      _amountString = sms.amount.toStringAsFixed(0);
      _descriptionController.text = sms.originalMessage;
      _selectedType = sms.transactionType.toLowerCase() == 'credit'
          ? TransactionType.income
          : TransactionType.expense;
      _selectedDate = sms.date;
      final suggested = TransactionParser.suggestCategory(sms.originalMessage);
      if (suggested != null) _selectedCategory = suggested;
      if (_selectedType == TransactionType.income) {
        _typeToggleController.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _typeToggleController.dispose();
    _amountBounceController.dispose();
    super.dispose();
  }

  void _onKeyTap(String key) {
    HapticFeedback.lightImpact();
    _amountBounceController.forward(from: 0);
    setState(() {
      if (key == '⌫') {
        _amountString = _amountString.length > 1
            ? _amountString.substring(0, _amountString.length - 1)
            : '0';
      } else if (key == '.') {
        if (!_amountString.contains('.')) _amountString = '$_amountString.';
      } else {
        if (_amountString == '0') {
          _amountString = key;
        } else if (_amountString.contains('.')) {
          final parts = _amountString.split('.');
          if (parts[1].length < 2) _amountString = '$_amountString$key';
        } else if (_amountString.length < 8) {
          _amountString = '$_amountString$key';
        }
      }
    });
  }

  double get _amount => double.tryParse(_amountString) ?? 0.0;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String get _formattedAmount {
    final parts = _amountString.split('.');
    final intPart = int.tryParse(parts[0]) ?? 0;
    final formatted = NumberFormat('#,##,###').format(intPart);
    return parts.length > 1 ? '$formatted.${parts[1]}' : formatted;
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _saveTransaction() async {
    if (_amount <= 0) {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      showDesignSystemSnackBar(
        context: context,
        message: 'Enter an amount greater than ₹0',
        isError: true,
      );
      return;
    }
    if (_selectedCategory == null) {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      showDesignSystemSnackBar(
        context: context,
        message: 'Pick a category first',
        isError: true,
      );
      return;
    }

    final title = _titleController.text.trim().isEmpty
        ? _selectedCategory!
        : _titleController.text.trim();

    setState(() => _isLoading = true);

    try {
      final expense = Expense(
        id: widget.expense?.id ??
            (DateTime.now().millisecondsSinceEpoch.toString() +
                (widget.smsTransaction?.id ?? '')),
        title: title,
        amount: _amount,
        date: _selectedDate,
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        type: _selectedType,
      );

      if (widget.expense != null) {
        await _firestoreService.updateExpense(expense);
      } else {
        await _firestoreService.addExpense(expense);
      }

      if (_selectedType == TransactionType.expense && _isSameDay(_selectedDate, DateTime.now())) {
        await ReminderService().markLoggedToday();
      }

      if (!mounted) return;
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      widget.onTransactionSaved();
      Navigator.pop(context);

      showDesignSystemSnackBar(
        context: context,
        message: widget.expense != null ? 'Updated!' : 'Added!',
      );
    } catch (_) {
      if (!mounted) return;
      showDesignSystemSnackBar(
        context: context,
        message: "Couldn't save. Please try again.",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _customAddCategoryDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: DesignSystemCard(
            glass: true,
            padding: const EdgeInsets.all(AppDesignSystem.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('New Category',
                    style: Theme.of(context).textTheme.headlineSmall),
                const VSpace.md(),
                DesignSystemTextField(
                  controller: controller,
                  label: 'Category Name',
                  hint: 'e.g., Subscriptions',
                  icon: Icons.category_rounded,
                ),
                const VSpace.lg(),
                Row(
                  children: [
                    Expanded(
                        child: SecondaryButton(
                            text: 'Cancel',
                            onPressed: () => Navigator.pop(context))),
                    const HSpace.md(),
                    Expanded(
                        child: GradientButton(
                            text: 'Add',
                            onPressed: () =>
                                Navigator.pop(context, controller.text.trim()))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((value) async {
      if (value is String && value.isNotEmpty) {
        final newCat = model.Category.fromIconData(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: value,
          iconData: Icons.category_rounded,
          type: _selectedType == TransactionType.income
              ? model.CategoryType.income
              : model.CategoryType.expense,
        );
        await _categoryService.addCategory(newCat);
        await _loadCategories();
        setState(() => _selectedCategory = value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isExpense = _selectedType == TransactionType.expense;
    final accentColor =
        isExpense ? AppDesignSystem.error : AppDesignSystem.success;

    return Container(
      height: MediaQuery.of(context).size.height * 0.93,
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystem.darkCanvas : Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppDesignSystem.r24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                const Spacer(),
                Text(
                  widget.expense != null ? 'Edit Transaction' : 'New Transaction',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
                const Spacer(),
                _DateChip(
                  date: _selectedDate,
                  onTap: _selectDate,
                ),
              ],
            ),
          ),

          // Type toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: _TypeToggle(
              selectedType: _selectedType,
              onChanged: _onTypeChanged,
              isDark: isDark,
            ),
          ),

          const SizedBox(height: 8),

          // Amount display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ScaleTransition(
              scale: _amountBounce,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: accentColor.withValues(alpha: 0.25), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: (theme.textTheme.headlineLarge ?? const TextStyle())
                          .copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                      ),
                      child: const Text('₹'),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style:
                            (theme.textTheme.displaySmall ?? const TextStyle())
                                .copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          fontSize: _formattedAmount.length > 7 ? 28 : 36,
                        ),
                        child: Text(
                          _formattedAmount,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Category row
          SizedBox(
            height: 48,
            child: _categoriesLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _CategoryRow(
                    categories: _categories,
                    selectedType: _selectedType,
                    selectedCategory: _selectedCategory,
                    accentColor: accentColor,
                    onCategorySelected: (name) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = name);
                    },
                    onAddCategory: _customAddCategoryDialog,
                  ),
          ),

          // Quick recurring chips
          if (widget.expense == null && _recurringOptions.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _recurringOptions
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: Icon(Icons.bolt_rounded,
                                size: 13,
                                color: theme.colorScheme.primary),
                            label: Text(t.title,
                                style: const TextStyle(fontSize: 12)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _amountString = t.amount.toStringAsFixed(0);
                                _titleController.text = t.title;
                                _selectedType = TransactionType.expense;
                                if (_categories.any((c) => c.name == t.category)) {
                                  _selectedCategory = t.category;
                                }
                              });
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Title field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'What\'s this for? (optional)',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
                prefixIcon: Icon(Icons.edit_note_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),

          const Spacer(),

          // Numeric keypad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _NumericKeypad(onKeyTap: _onKeyTap),
          ),

          const SizedBox(height: 10),

          // Save button
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: GradientButton(
              text: _isLoading
                  ? 'Saving...'
                  : widget.expense != null
                      ? 'Update Transaction'
                      : isExpense
                          ? 'Add Expense'
                          : 'Add Income',
              onPressed: _isLoading ? null : _saveTransaction,
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateChip({required this.date, required this.onTap});

  bool get _isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get _isYesterday {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return date.year == y.year && date.month == y.month && date.day == y.day;
  }

  String get _label => _isToday
      ? 'Today'
      : _isYesterday
          ? 'Yesterday'
          : DateFormat('MMM d').format(date);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 13, color: theme.colorScheme.primary),
            const SizedBox(width: 5),
            Text(
              _label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final TransactionType selectedType;
  final ValueChanged<TransactionType> onChanged;
  final bool isDark;

  const _TypeToggle({
    required this.selectedType,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(50),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              icon: Icons.north_east_rounded,
              label: 'Expense',
              isSelected: selectedType == TransactionType.expense,
              color: AppDesignSystem.error,
              onTap: () => onChanged(TransactionType.expense),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              icon: Icons.south_west_rounded,
              label: 'Income',
              isSelected: selectedType == TransactionType.income,
              color: AppDesignSystem.success,
              onTap: () => onChanged(TransactionType.income),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final List<model.Category> categories;
  final TransactionType selectedType;
  final String? selectedCategory;
  final Color accentColor;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onAddCategory;

  const _CategoryRow({
    required this.categories,
    required this.selectedType,
    required this.selectedCategory,
    required this.accentColor,
    required this.onCategorySelected,
    required this.onAddCategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeName = selectedType == TransactionType.income
        ? model.CategoryType.income.name
        : model.CategoryType.expense.name;
    final filtered =
        categories.where((c) => c.type.name == typeName).toList();

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        ...filtered.map((cat) {
          final isSelected = selectedCategory == cat.name;
          final color = isSelected
              ? accentColor
              : theme.colorScheme.onSurface.withValues(alpha: 0.55);

          return GestureDetector(
            onTap: () => onCategorySelected(cat.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.1)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.45)
                      : theme.colorScheme.outline.withValues(alpha: 0.15),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.icon, size: 15, color: color),
                  const SizedBox(width: 6),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        GestureDetector(
          onTap: onAddCategory,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded,
                    size: 15, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'New',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onKeyTap;

  const _NumericKeypad({required this.onKeyTap});

  static const _keys = ['7', '8', '9', '4', '5', '6', '1', '2', '3', '.', '0', '⌫'];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _keys.length,
      itemBuilder: (context, index) {
        final key = _keys[index];
        return _KeypadButton(
          label: key,
          isBackspace: key == '⌫',
          onTap: () => onKeyTap(key),
        );
      },
    );
  }
}

class _KeypadButton extends StatefulWidget {
  final String label;
  final bool isBackspace;
  final VoidCallback onTap;

  const _KeypadButton({
    required this.label,
    required this.isBackspace,
    required this.onTap,
  });

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 80), vsync: this, value: 1.0);
    _scale = Tween<double>(begin: 0.90, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isBackspace
                ? AppDesignSystem.error.withValues(alpha: 0.08)
                : isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isBackspace
                  ? AppDesignSystem.error.withValues(alpha: 0.2)
                  : theme.colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
          child: Center(
            child: widget.isBackspace
                ? const Icon(Icons.backspace_outlined,
                    size: 20, color: AppDesignSystem.error)
                : Text(
                    widget.label,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
