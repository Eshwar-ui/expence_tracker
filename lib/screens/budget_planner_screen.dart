import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';
import '../utils/app_design_system.dart';
import '../widgets/design_system_components.dart';

class BudgetPlannerScreen extends StatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  State<BudgetPlannerScreen> createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends State<BudgetPlannerScreen> {
  final BudgetService _budgetService = BudgetService();
  List<Budget> _budgets = [];
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _budgetService.updateBudgetSpentAmounts();
      final budgets = await _budgetService.getBudgets();
      final analytics = await _budgetService.getBudgetAnalytics();
      if (!mounted) return;
      setState(() {
        _budgets = budgets;
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: PremiumAppBar(
        title: 'Budget Planner',
        actions: [
          IconButton(
            onPressed: _showAddBudgetDialog,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            onPressed: _loadBudgets,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const DesignSystemLoading()
          : _budgets.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return DesignSystemEmptyState(
      icon: Icons.account_balance_wallet_rounded,
      title: 'No Budgets',
      message: 'Plan your expenses by setting up categorical budgets.',
      action: GradientButton(
        text: 'Create First Budget',
        onPressed: _showAddBudgetDialog,
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadBudgets,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDesignSystem.s24),
        child: Column(
          children: [
            _buildOverview(),
            const VSpace.xl(),
            _buildFinancialPlanCard(),
            const VSpace.xl(),
            _buildBudgetsList(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview() {
    final total = _analytics['totalBudgeted'] ?? 0.0;
    final spent = _analytics['totalSpent'] ?? 0.0;

    return DesignSystemCard(
      glass: true,
      padding: const EdgeInsets.all(AppDesignSystem.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Budgets',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const VSpace.sm(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${spent.toStringAsFixed(0)} / ₹${total.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              DesignSystemBadge(
                text:
                    '${total > 0 ? ((spent / total) * 100).toStringAsFixed(0) : 0}%',
                color: spent > total
                    ? AppDesignSystem.error
                    : AppDesignSystem.success,
              ),
            ],
          ),
          const VSpace.lg(),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
            child: LinearProgressIndicator(
              value: total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0,
              minHeight: 12,
              color: spent > total
                  ? AppDesignSystem.error
                  : AppDesignSystem.brandPrimary,
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialPlanCard() {
    final income = _analytics['monthlyIncome'] ?? 0.0;
    final target = _analytics['savingsTarget'] ?? 0.0;

    return DesignSystemCard(
      padding: const EdgeInsets.all(AppDesignSystem.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Plan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: _showEditPlanDialog,
                icon: const Icon(Icons.edit_note_rounded),
                color: AppDesignSystem.brandPrimary,
              ),
            ],
          ),
          const VSpace.md(),
          Row(
            children: [
              Expanded(
                child: _buildPlanStat(
                  'Monthly Income',
                  '₹${income.toStringAsFixed(0)}',
                  Icons.payments_rounded,
                ),
              ),
              const HSpace.md(),
              Expanded(
                child: _buildPlanStat(
                  'Savings Target',
                  '₹${target.toStringAsFixed(0)}',
                  Icons.savings_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.s16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppDesignSystem.r16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppDesignSystem.brandPrimary),
          const VSpace.xs(),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  void _showEditPlanDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BudgetPlanDialog(
        budgetService: _budgetService,
        onSaved: _loadBudgets,
        currentIncome: (_analytics['monthlyIncome'] ?? 0.0).toDouble(),
        currentTarget: (_analytics['savingsTarget'] ?? 0.0).toDouble(),
      ),
    );
  }

  Widget _buildBudgetsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categorical Budgets',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const VSpace.md(),
        ..._budgets.map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: AppDesignSystem.s16),
            child: DesignSystemCard(
              onTap: () => _showEditBudgetDialog(b),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        b.category,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '₹${b.remaining.toStringAsFixed(0)} left',
                        style: TextStyle(
                          color: b.remaining < 0
                              ? AppDesignSystem.error
                              : AppDesignSystem.success,
                        ),
                      ),
                    ],
                  ),
                  const VSpace.sm(),
                  Text(
                    '₹${b.spent.toStringAsFixed(0)} of ₹${b.limit.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const VSpace.md(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: b.limit > 0
                          ? (b.spent / b.limit).clamp(0.0, 1.0)
                          : 0.0,
                      minHeight: 6,
                      color: b.spent > b.limit
                          ? AppDesignSystem.error
                          : AppDesignSystem.brandSecondary,
                      backgroundColor: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddBudgetDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _BudgetDialog(budgetService: _budgetService, onSaved: _loadBudgets),
    );
  }

  void _showEditBudgetDialog(Budget b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BudgetDialog(
        budgetService: _budgetService,
        budget: b,
        onSaved: _loadBudgets,
      ),
    );
  }
}

class _BudgetDialog extends StatefulWidget {
  final BudgetService budgetService;
  final Budget? budget;
  final VoidCallback onSaved;
  const _BudgetDialog({
    required this.budgetService,
    this.budget,
    required this.onSaved,
  });
  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  final _catCtrl = TextEditingController();
  final _limCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _catCtrl.text = widget.budget!.category;
      _limCtrl.text = widget.budget!.limit.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              widget.budget == null ? 'New Budget' : 'Edit Budget',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const VSpace.xl(),
          DesignSystemTextField(
            controller: _catCtrl,
            label: 'Category',
            hint: 'e.g. Shopping, Food',
            icon: Icons.category_rounded,
          ),
          const VSpace.lg(),
          DesignSystemTextField(
            controller: _limCtrl,
            label: 'Monthly Limit',
            hint: '0.00',
            icon: Icons.account_balance_wallet_rounded,
            keyboardType: TextInputType.number,
          ),
          const VSpace.xl(),
          GradientButton(
            text: widget.budget == null ? 'Create Budget' : 'Save Changes',
            isLoading: _loading,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_catCtrl.text.isEmpty || _limCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final budget = Budget(
        id: widget.budget?.id ?? widget.budgetService.generateId(),
        userId: FirebaseAuth.instance.currentUser!.uid,
        category: _catCtrl.text,
        limit: double.parse(_limCtrl.text),
        spent: widget.budget?.spent ?? 0.0,
        frequency: BudgetFrequency.monthly,
        createdAt: widget.budget?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      if (widget.budget == null)
        await widget.budgetService.createBudget(budget);
      else
        await widget.budgetService.updateBudget(budget);
      widget.onSaved();
      Navigator.pop(context);
    } finally {
      setState(() => _loading = false);
    }
  }
}

class _BudgetPlanDialog extends StatefulWidget {
  final BudgetService budgetService;
  final VoidCallback onSaved;
  final double currentIncome;
  final double currentTarget;

  const _BudgetPlanDialog({
    required this.budgetService,
    required this.onSaved,
    required this.currentIncome,
    required this.currentTarget,
  });

  @override
  State<_BudgetPlanDialog> createState() => _BudgetPlanDialogState();
}

class _BudgetPlanDialogState extends State<_BudgetPlanDialog> {
  late TextEditingController _incomeCtrl;
  late TextEditingController _targetCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _incomeCtrl = TextEditingController(
      text: widget.currentIncome.toStringAsFixed(0),
    );
    _targetCtrl = TextEditingController(
      text: widget.currentTarget.toStringAsFixed(0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text('Edit Monthly Plan', style: theme.textTheme.headlineSmall),
          const VSpace.xl(),
          DesignSystemTextField(
            controller: _incomeCtrl,
            label: 'Monthly Income',
            hint: '0.00',
            icon: Icons.payments_rounded,
            keyboardType: TextInputType.number,
          ),
          const VSpace.lg(),
          DesignSystemTextField(
            controller: _targetCtrl,
            label: 'Savings Target',
            hint: '0.00',
            icon: Icons.savings_rounded,
            keyboardType: TextInputType.number,
          ),
          const VSpace.xl(),
          GradientButton(
            text: 'Save Plan',
            isLoading: _loading,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final plan = BudgetPlan(
        id: FirebaseAuth.instance.currentUser!.uid,
        userId: FirebaseAuth.instance.currentUser!.uid,
        monthlyIncome: double.tryParse(_incomeCtrl.text) ?? 0.0,
        savingsTarget: double.tryParse(_targetCtrl.text) ?? 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await widget.budgetService.saveBudgetPlan(plan);
      widget.onSaved();
      Navigator.pop(context);
    } finally {
      setState(() => _loading = false);
    }
  }
}
