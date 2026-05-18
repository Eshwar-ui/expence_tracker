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

  /// Pre-fills the modal with parsed values (e.g. from voice quick-add).
  /// Unlike [expense], this keeps the modal in *add* mode — the id is not
  /// reused, and the save path calls `addExpense`, not `updateExpense`.
  final Expense? prefill;
  final VoidCallback onTransactionSaved;

  const ExpenseDialog({
    super.key,
    this.smsTransaction,
    this.expense,
    this.prefill,
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

  String _amountString = '0';

  late AnimationController _amountBounceController;
  late Animation<double> _amountBounce;

  @override
  void initState() {
    super.initState();
    _amountBounceController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
      value: 1.0,
    );
    _amountBounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _amountBounceController,
      curve: Curves.easeOut,
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
    if (_selectedType == type) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedType = type;
      _ensureValidCategory();
    });
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
    } else if (widget.prefill != null) {
      final p = widget.prefill!;
      _titleController.text = p.title;
      _amountString = p.amount == p.amount.truncateToDouble()
          ? p.amount.toStringAsFixed(0)
          : p.amount.toStringAsFixed(2);
      _selectedType = p.type;
      _selectedCategory = p.category;
      _selectedDate = p.date;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppDesignSystem.brandPrimary,
                ),
          ),
          child: child!,
        );
      },
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

      StreakResult? streakResult;
      if (_selectedType == TransactionType.expense &&
          _isSameDay(_selectedDate, DateTime.now())) {
        streakResult = await ReminderService().markLoggedToday();
      }

      if (!mounted) return;
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      widget.onTransactionSaved();
      Navigator.pop(context);

      final milestone = streakResult?.milestoneReached;
      showDesignSystemSnackBar(
        context: context,
        message: milestone != null
            ? '🔥 $milestone-day streak! Keep it going.'
            : widget.expense != null
                ? 'Updated!'
                : 'Added!',
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
    final accentGradient = isExpense
        ? AppDesignSystem.errorGradient
        : AppDesignSystem.successGradient;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: MediaQuery.of(context).size.height * 0.93,
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystem.darkCanvas : AppDesignSystem.lightCanvas,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppDesignSystem.r24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          _DragHandle(isDark: isDark),
          _Header(
            isEditing: widget.expense != null,
            date: _selectedDate,
            onClose: () => Navigator.pop(context),
            onDateTap: _selectDate,
          ),
          const VSpace.sm(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.s20),
            child: _TypeToggle(
              selectedType: _selectedType,
              onChanged: _onTypeChanged,
              isDark: isDark,
            ),
          ),

          const VSpace.md(),

          // Hero amount display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.s20),
            child: ScaleTransition(
              scale: _amountBounce,
              child: _AmountHero(
                amountString: _amountString,
                formattedAmount: _formattedAmount,
                accentColor: accentColor,
                accentGradient: accentGradient,
                isDark: isDark,
              ),
            ),
          ),

          const VSpace.md(),

          // Categories
          SizedBox(
            height: 44,
            child: _categoriesLoading
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
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
            const VSpace.sm(),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignSystem.s20),
                itemCount: _recurringOptions.length,
                separatorBuilder: (_, __) => const HSpace.sm(),
                itemBuilder: (context, i) {
                  final t = _recurringOptions[i];
                  return _RecurringChip(
                    title: t.title,
                    amount: t.amount,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _amountBounceController.forward(from: 0);
                      setState(() {
                        _amountString = t.amount.toStringAsFixed(0);
                        _titleController.text = t.title;
                        _selectedType = TransactionType.expense;
                        if (_categories.any((c) => c.name == t.category)) {
                          _selectedCategory = t.category;
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],

          const VSpace.md(),

          // Title field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.s20),
            child: _InlineNoteField(
              controller: _titleController,
              isDark: isDark,
            ),
          ),

          const Spacer(),

          // Keypad — shrinks when the soft keyboard is up
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Padding(
              key: ValueKey(isKeyboardOpen),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.s20),
              child: _NumericKeypad(
                onKeyTap: _onKeyTap,
                accentColor: accentColor,
                isDark: isDark,
                isCompact: isKeyboardOpen,
              ),
            ),
          ),

          SizedBox(height: isKeyboardOpen ? AppDesignSystem.s8 : AppDesignSystem.s16),

          // Save button
          Padding(
            padding: EdgeInsets.only(
              left: AppDesignSystem.s20,
              right: AppDesignSystem.s20,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppDesignSystem.s16,
            ),
            child: GradientButton(
              text: _isLoading
                  ? 'Saving...'
                  : widget.expense != null
                      ? 'Update Transaction'
                      : isExpense
                          ? 'Add Expense'
                          : 'Add Income',
              icon: _isLoading
                  ? null
                  : (isExpense
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded),
              gradient: accentGradient,
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

class _DragHandle extends StatelessWidget {
  final bool isDark;
  const _DragHandle({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: AppDesignSystem.s12, bottom: AppDesignSystem.s4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isEditing;
  final DateTime date;
  final VoidCallback onClose;
  final VoidCallback onDateTap;

  const _Header({
    required this.isEditing,
    required this.date,
    required this.onClose,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDesignSystem.s16,
        AppDesignSystem.s8,
        AppDesignSystem.s16,
        AppDesignSystem.s4,
      ),
      child: Row(
        children: [
          _IconButton(
            icon: Icons.close_rounded,
            onTap: onClose,
            isDark: isDark,
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                isEditing ? 'Edit Transaction' : 'New Transaction',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isEditing ? 'Update details below' : 'Track your spending',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const Spacer(),
          _DateChip(date: date, onTap: onDateTap),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.04),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppDesignSystem.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
            border: Border.all(
              color: AppDesignSystem.brandPrimary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 12, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                _label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
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
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              icon: Icons.arrow_upward_rounded,
              label: 'Expense',
              isSelected: selectedType == TransactionType.expense,
              gradient: AppDesignSystem.errorGradient,
              shadowColor: AppDesignSystem.error,
              onTap: () => onChanged(TransactionType.expense),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              icon: Icons.arrow_downward_rounded,
              label: 'Income',
              isSelected: selectedType == TransactionType.income,
              gradient: AppDesignSystem.successGradient,
              shadowColor: AppDesignSystem.success,
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
  final LinearGradient gradient;
  final Color shadowColor;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.gradient,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? gradient : null,
          borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountHero extends StatelessWidget {
  final String amountString;
  final String formattedAmount;
  final Color accentColor;
  final LinearGradient accentGradient;
  final bool isDark;

  const _AmountHero({
    required this.amountString,
    required this.formattedAmount,
    required this.accentColor,
    required this.accentGradient,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = amountString == '0';
    final displaySize = formattedAmount.length > 8
        ? 30.0
        : formattedAmount.length > 5
            ? 38.0
            : 44.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(
          vertical: AppDesignSystem.s16, horizontal: AppDesignSystem.s20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: isDark ? 0.18 : 0.10),
            accentColor.withValues(alpha: isDark ? 0.06 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.r24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Currency badge
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: accentGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '₹',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const HSpace.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Amount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accentColor.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: (theme.textTheme.displaySmall ?? const TextStyle())
                      .copyWith(
                    color: isEmpty
                        ? accentColor.withValues(alpha: 0.35)
                        : accentColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                    fontSize: displaySize,
                    height: 1.0,
                  ),
                  child: Text(
                    formattedAmount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final isDark = theme.brightness == Brightness.dark;
    final typeName = selectedType == TransactionType.income
        ? model.CategoryType.income.name
        : model.CategoryType.expense.name;
    final filtered =
        categories.where((c) => c.type.name == typeName).toList();

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.s20),
      itemCount: filtered.length + 1,
      separatorBuilder: (_, __) => const HSpace.sm(),
      itemBuilder: (context, i) {
        if (i == filtered.length) {
          return _CategoryPill(
            icon: Icons.add_rounded,
            label: 'New',
            color: theme.colorScheme.primary,
            isSelected: false,
            isAdd: true,
            isDark: isDark,
            onTap: onAddCategory,
          );
        }
        final cat = filtered[i];
        final isSelected = selectedCategory == cat.name;
        return _CategoryPill(
          icon: cat.icon,
          label: cat.name,
          color: accentColor,
          isSelected: isSelected,
          isAdd: false,
          isDark: isDark,
          onTap: () => onCategorySelected(cat.name),
        );
      },
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final bool isAdd;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.isAdd,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isSelected
        ? color
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.45)
                : isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.18)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: isAdd ? 14 : 13,
                color: isAdd ? theme.colorScheme.primary : textColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isAdd ? theme.colorScheme.primary : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringChip extends StatelessWidget {
  final String title;
  final double amount;
  final VoidCallback onTap;

  const _RecurringChip({
    required this.title,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppDesignSystem.brandPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
          border: Border.all(
            color: AppDesignSystem.brandPrimary.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded,
                size: 13, color: AppDesignSystem.brandPrimary),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppDesignSystem.darkTextHigh
                    : AppDesignSystem.textHigh,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppDesignSystem.brandPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
              ),
              child: Text(
                '₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.brandPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineNoteField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;

  const _InlineNoteField({
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(AppDesignSystem.r16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.sentences,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: "What's this for? (optional)",
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          prefixIcon: Icon(
            Icons.edit_note_rounded,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          isDense: true,
        ),
      ),
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onKeyTap;
  final Color accentColor;
  final bool isDark;
  final bool isCompact;

  const _NumericKeypad({
    required this.onKeyTap,
    required this.accentColor,
    required this.isDark,
    this.isCompact = false,
  });

  static const _keys = ['7', '8', '9', '4', '5', '6', '1', '2', '3', '.', '0', '⌫'];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: isCompact ? 5.0 : 2.6,
        crossAxisSpacing: AppDesignSystem.s8,
        mainAxisSpacing: isCompact ? 6 : AppDesignSystem.s8,
      ),
      itemCount: _keys.length,
      itemBuilder: (context, index) {
        final key = _keys[index];
        final isBackspace = key == '⌫';
        final isDot = key == '.';
        return _KeypadButton(
          label: key,
          isBackspace: isBackspace,
          isDot: isDot,
          accentColor: accentColor,
          isDark: isDark,
          isCompact: isCompact,
          onTap: () => onKeyTap(key),
        );
      },
    );
  }
}

class _KeypadButton extends StatefulWidget {
  final String label;
  final bool isBackspace;
  final bool isDot;
  final Color accentColor;
  final bool isDark;
  final bool isCompact;
  final VoidCallback onTap;

  const _KeypadButton({
    required this.label,
    required this.isBackspace,
    required this.isDot,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
    this.isCompact = false,
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
        duration: const Duration(milliseconds: 90), vsync: this, value: 1.0);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bgColor {
    if (widget.isBackspace) {
      return AppDesignSystem.error.withValues(alpha: widget.isDark ? 0.12 : 0.08);
    }
    if (widget.isDot) {
      return AppDesignSystem.brandPrimary
          .withValues(alpha: widget.isDark ? 0.12 : 0.08);
    }
    return widget.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.035);
  }

  Color get _borderColor {
    if (widget.isBackspace) {
      return AppDesignSystem.error.withValues(alpha: 0.22);
    }
    if (widget.isDot) {
      return AppDesignSystem.brandPrimary.withValues(alpha: 0.22);
    }
    return widget.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
  }

  Color get _fgColor {
    if (widget.isBackspace) return AppDesignSystem.error;
    if (widget.isDot) return AppDesignSystem.brandPrimary;
    return Theme.of(context).colorScheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(
                widget.isCompact ? AppDesignSystem.r12 : AppDesignSystem.r16),
            border: Border.all(color: _borderColor),
          ),
          child: Center(
            child: widget.isBackspace
                ? Icon(
                    Icons.backspace_outlined,
                    size: widget.isCompact ? 16 : 20,
                    color: _fgColor,
                  )
                : Text(
                    widget.label,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: widget.isCompact ? 16 : 22,
                      color: _fgColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
