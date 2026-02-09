import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_sms.dart';
import '../models/expence.dart';
import '../models/category.dart' as model;
import '../services/firestore_service.dart';
import '../services/category_service.dart';
import '../utils/app_design_system.dart';
import '../widgets/design_system_components.dart';

import '../utils/transaction_parser.dart';

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

class _ExpenseDialogState extends State<ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final CategoryService _categoryService = CategoryService();
  final FirestoreService _firestoreService = FirestoreService();

  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _categoriesLoading = true;
  List<model.Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initializeFields();
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

    final isIncome = _selectedType == TransactionType.income;
    final typeName = isIncome
        ? model.CategoryType.income.name
        : model.CategoryType.expense.name;

    final filtered = _categories.where((c) => c.type.name == typeName).toList();

    if (_selectedCategory == null ||
        !filtered.any((c) => c.name == _selectedCategory)) {
      if (filtered.isNotEmpty) {
        _selectedCategory = filtered.first.name;
      }
    }
  }

  void _onTypeChanged(TransactionType type) {
    setState(() {
      _selectedType = type;
      _ensureValidCategory();
    });
    _loadCategories(); // Refresh from service as well
  }

  void _initializeFields() {
    if (widget.expense != null) {
      // Editing existing expense
      _titleController.text = widget.expense!.title;
      _amountController.text = widget.expense!.amount.toString();
      _descriptionController.text = widget.expense!.description;
      _selectedType = widget.expense!.type;
      _selectedCategory = widget.expense!.category;
      _selectedDate = widget.expense!.date;
    } else if (widget.smsTransaction != null) {
      // Creating from SMS - normalize the title automatically
      final rawDescription = widget.smsTransaction!.description;
      final originalMessage = widget.smsTransaction!.originalMessage;

      // Use the normalizer to create a clean, readable title
      _titleController.text = TransactionParser.normalizeDescription(
        rawDescription.isNotEmpty ? rawDescription : originalMessage,
      );

      _amountController.text = widget.smsTransaction!.amount.toString();
      _descriptionController.text = originalMessage;
      _selectedType =
          widget.smsTransaction!.transactionType.toLowerCase() == 'credit'
              ? TransactionType.income
              : TransactionType.expense;
      _selectedDate = widget.smsTransaction!.date;

      // Auto-suggest category based on merchant
      final suggestedCategory = TransactionParser.suggestCategory(
        originalMessage,
      );
      if (suggestedCategory != null) {
        _selectedCategory = suggestedCategory;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      showDesignSystemSnackBar(
        context: context,
        message: 'Please select a category',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final expense = Expense(
        id: widget.expense?.id ??
            (DateTime.now().millisecondsSinceEpoch.toString() +
                (widget.smsTransaction?.id ?? '')),
        title: _titleController.text.trim(),
        amount: double.tryParse(_amountController.text) ?? 0.0,
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

      if (!mounted) return;

      widget.onTransactionSaved();
      Navigator.pop(context);

      showDesignSystemSnackBar(
        context: context,
        message: widget.expense != null
            ? 'Transaction updated!'
            : 'Transaction added!',
      );
    } catch (e) {
      if (!mounted) return;
      showDesignSystemSnackBar(
        context: context,
        message: 'Error: $e',
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
                Text(
                  'New Category',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
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
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const HSpace.md(),
                    Expanded(
                      child: GradientButton(
                        text: 'Add',
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((value) async {
      if (value != null && value is String && value.isNotEmpty) {
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
        setState(() {
          _selectedCategory = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredCategories =
        _categories.where((c) => c.type.name == _selectedType.name).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystem.darkCanvas : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDesignSystem.r24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const VSpace.lg(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.brandPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.expense != null
                          ? Icons.edit_rounded
                          : Icons.add_rounded,
                      color: AppDesignSystem.brandPrimary,
                      size: 28,
                    ),
                  ),
                  const HSpace.md(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.expense != null
                              ? 'Edit Transaction'
                              : 'New Transaction',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          widget.expense != null
                              ? 'Update your record'
                              : 'Add a manual or SMS record',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface,
                    ),
                  ),
                ],
              ),
              const VSpace.lg(),

              // Type Toggle
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Expense')),
                      selected: _selectedType == TransactionType.expense,
                      onSelected: (val) {
                        if (val) _onTypeChanged(TransactionType.expense);
                      },
                      selectedColor: AppDesignSystem.error.withOpacity(0.2),
                    ),
                  ),
                  const HSpace.sm(),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Income')),
                      selected: _selectedType == TransactionType.income,
                      onSelected: (val) {
                        if (val) _onTypeChanged(TransactionType.income);
                      },
                      selectedColor: AppDesignSystem.success.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
              const VSpace.lg(),

              DesignSystemTextField(
                controller: _titleController,
                label: 'Description / Title',
                hint: 'What was this for?',
                icon: Icons.description_rounded,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const VSpace.md(),
              Row(
                children: [
                  Expanded(
                    child: DesignSystemTextField(
                      controller: _amountController,
                      label: 'Amount (₹)',
                      hint: '0.00',
                      icon: Icons.currency_rupee_rounded,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Must be > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const HSpace.md(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectDate,
                          borderRadius: BorderRadius.circular(
                            AppDesignSystem.r16,
                          ),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(
                                AppDesignSystem.r16,
                              ),
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(
                                  0.1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const HSpace.sm(),
                                Text(
                                  DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(_selectedDate),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const VSpace.md(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Category',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _customAddCategoryDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('New', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _categoriesLoading
                  ? const LinearProgressIndicator()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(
                          AppDesignSystem.r16,
                        ),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedCategory,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: filteredCategories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category.name,
                                  child: Row(
                                    children: [
                                      Icon(
                                        category.icon,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const HSpace.sm(),
                                      Text(category.name),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedCategory = value!),
                        ),
                      ),
                    ),
              const VSpace.md(),
              DesignSystemTextField(
                controller: _descriptionController,
                label: 'Notes',
                hint: 'Additional details...',
                icon: Icons.notes_rounded,
              ),
              const VSpace.xl(),
              GradientButton(
                text: widget.expense != null
                    ? 'Update Transaction'
                    : 'Save Transaction',
                onPressed: _isLoading ? null : _saveTransaction,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
