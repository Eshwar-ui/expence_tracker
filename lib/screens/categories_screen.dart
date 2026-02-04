import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../utils/app_design_system.dart';
import '../widgets/design_system_components.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  final CategoryService _categoryService = CategoryService();
  late TabController _tabController;
  bool _isLoading = true;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final cats = await _categoryService.getCategories();
    setState(() {
      _categories = cats;
      _isLoading = false;
    });
  }

  Future<void> _addOrEditCategory([Category? category]) async {
    final nameController = TextEditingController(text: category?.name);
    IconData selectedIcon = category?.icon ?? Icons.category_rounded;
    CategoryType selectedType = category?.type ??
        (_tabController.index == 0
            ? CategoryType.expense
            : CategoryType.income);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: DesignSystemCard(
              glass: true,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category == null ? 'Add Category' : 'Edit Category',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const VSpace.lg(),
                    DesignSystemTextField(
                      controller: nameController,
                      label: 'Category Name',
                      hint: 'Enter name',
                      icon: Icons.label_outline_rounded,
                    ),
                    const VSpace.md(),
                    Text(
                      'Category Type',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                    const VSpace.xs(),
                    Row(
                      children: [
                        _buildTypeChip(
                          'Expense',
                          selectedType == CategoryType.expense,
                          () => setDialogState(
                              () => selectedType = CategoryType.expense),
                        ),
                        const HSpace.sm(),
                        _buildTypeChip(
                          'Income',
                          selectedType == CategoryType.income,
                          () => setDialogState(
                              () => selectedType = CategoryType.income),
                        ),
                      ],
                    ),
                    const VSpace.md(),
                    Text(
                      'Choose Icon',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                    const VSpace.sm(),
                    SizedBox(
                      height: 180,
                      child: GridView.count(
                        crossAxisCount: 5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          Icons.restaurant_rounded,
                          Icons.directions_bus_rounded,
                          Icons.movie_rounded,
                          Icons.shopping_bag_rounded,
                          Icons.receipt_long_rounded,
                          Icons.medical_services_rounded,
                          Icons.school_rounded,
                          Icons.more_horiz_rounded,
                          Icons.payments_rounded,
                          Icons.work_rounded,
                          Icons.trending_up_rounded,
                          Icons.card_giftcard_rounded,
                          Icons.replay_rounded,
                          Icons.home_rounded,
                          Icons.electrical_services_rounded,
                          Icons.water_drop_rounded,
                          Icons.fitness_center_rounded,
                          Icons.pets_rounded,
                          Icons.flight_rounded,
                          Icons.sports_esports_rounded,
                        ]
                            .map((icon) => InkWell(
                                  onTap: () =>
                                      setDialogState(() => selectedIcon = icon),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: selectedIcon == icon
                                          ? AppDesignSystem.brandPrimary
                                              .withOpacity(0.1)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: selectedIcon == icon
                                            ? AppDesignSystem.brandPrimary
                                            : AppDesignSystem.brandPrimary
                                                .withOpacity(0.1),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(icon,
                                        size: 20,
                                        color: selectedIcon == icon
                                            ? AppDesignSystem.brandPrimary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.5)),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const VSpace.lg(),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            text: 'Cancel',
                            onPressed: () => Navigator.pop(context, false),
                          ),
                        ),
                        const HSpace.md(),
                        Expanded(
                          child: GradientButton(
                            text: 'Save',
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      final newName = nameController.text.trim();

      // Check for duplicates (only for new categories)
      if (category == null) {
        final isDuplicate = _categories.any((c) =>
            c.name.toLowerCase() == newName.toLowerCase() &&
            c.type == selectedType);

        if (isDuplicate) {
          if (mounted) {
            showDesignSystemSnackBar(
              context: context,
              message:
                  'Category "$newName" already exists in ${selectedType.name}s',
              isError: true,
            );
          }
          return;
        }
      }

      final newCat = Category(
        id: category?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: newName,
        icon: selectedIcon,
        type: selectedType,
        isDefault: category?.isDefault ?? false,
      );

      try {
        await _categoryService.addCategory(newCat);
        _loadCategories();
        if (mounted) {
          showDesignSystemSnackBar(
            context: context,
            message: category == null
                ? 'Category added successfully'
                : 'Category updated successfully',
          );
        }
      } catch (e) {
        if (mounted) {
          showDesignSystemSnackBar(
            context: context,
            message: 'Failed to save category: $e',
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses =
        _categories.where((c) => c.type == CategoryType.expense).toList();
    final incomes =
        _categories.where((c) => c.type == CategoryType.income).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Income'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(expenses),
                _buildCategoryList(incomes),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditCategory(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryList(List<Category> categories) {
    if (categories.isEmpty) {
      return const Center(child: Text('No categories found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return DesignSystemCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppDesignSystem.brandPrimary.withOpacity(0.1),
              child: Icon(cat.icon, color: AppDesignSystem.brandPrimary),
            ),
            title: Text(cat.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(cat.isDefault ? 'Default' : 'Custom'),
            trailing: cat.isDefault
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _addOrEditCategory(cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: Colors.red),
                        onPressed: () {
                          showDesignSystemDialog(
                            context: context,
                            title: 'Delete Category',
                            message:
                                'Are you sure you want to delete "${cat.name}"?',
                            confirmLabel: 'Delete',
                            destructive: true,
                            onConfirm: () async {
                              try {
                                await _categoryService.deleteCategory(cat.id);
                                _loadCategories();
                                if (mounted) {
                                  showDesignSystemSnackBar(
                                    context: context,
                                    message: 'Category deleted successfully',
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  showDesignSystemSnackBar(
                                    context: context,
                                    message: 'Failed to delete category: $e',
                                    isError: true,
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildTypeChip(String label, bool selected, VoidCallback onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppDesignSystem.brandPrimary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected
            ? AppDesignSystem.brandPrimary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
