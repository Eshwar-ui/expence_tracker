import 'dart:async';
import 'dart:ui';

import 'package:expence_tracker/models/analytics.dart';
import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/screens/ai_predictions_screen.dart';
import 'package:expence_tracker/screens/scan_upi_screen.dart';
import 'package:expence_tracker/screens/smart_inbox_screen.dart';
import 'package:expence_tracker/services/analytics_service.dart';
import 'package:expence_tracker/services/home_balance_widget_service.dart';
import 'package:expence_tracker/services/pending_transaction_service.dart';
import 'package:expence_tracker/services/recurring_transaction_service.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/app_design_system.dart';
import 'expense_dialog.dart';

const String _rupee = '\u20B9';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AnalyticsService _analyticsService = AnalyticsService();
  final PendingTransactionService _pendingTransactionService =
      PendingTransactionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AnalyticsData? _analyticsData;
  User? _user;
  bool _isLoading = true;
  String? _loadError;
  late final AnimationController _animationController;

  String get _firstName {
    final name = _user?.displayName?.trim();
    if (name == null || name.isEmpty) {
      return 'User';
    }
    return name.split(' ').first;
  }

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _loadExpenses();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      try {
        await RecurringTransactionService().executeDueTransactions();
      } catch (_) {
        // Recurring execution should not block the dashboard.
      }

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end = now;

      final data = await _analyticsService.getAnalyticsData(
        startDate: start,
        endDate: end,
      );

      await HomeBalanceWidgetService.updateFromAnalytics(data);

      if (!mounted) return;
      setState(() {
        _analyticsData = data;
        _isLoading = false;
        _loadError = null;
      });

      unawaited(_animationController.forward(from: 0));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load the dashboard right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppDesignSystem.brandPrimary.withValues(alpha: 0.25),
              ),
            ),
          ),
          Positioned(
            top: 250,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppDesignSystem.brandSecondary.withValues(alpha: 0.2),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppDesignSystem.brandAccent.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadExpenses,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildHeader(),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDesignSystem.s24,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWalletCard(),
                          const VSpace.xl(),
                          _buildStatusBanner(),
                          if (_loadError != null) const VSpace.md(),
                          _buildOverviewGrid(),
                          const VSpace.xl(),
                          _buildQuickActions(),
                          const VSpace.xl(),
                          _buildInsightCard(),
                          const VSpace.xl(),
                          _buildRecentTransactionsHeader(),
                          const VSpace.md(),
                        ],
                      ),
                    ),
                  ),
                  _buildTransactionsList(),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.s24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,', style: theme.textTheme.bodyMedium),
                Text(_firstName, style: theme.textTheme.headlineMedium),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                backgroundImage: _user?.photoURL != null
                    ? NetworkImage(_user!.photoURL!)
                    : null,
                child: _user?.photoURL == null
                    ? const Icon(Icons.person_rounded)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
    if (_isLoading) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppDesignSystem.r24),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final data = _analyticsData;
    final balance = data?.balance ?? 0.0;
    final budgetUtilization =
        data?.budgetStatus.budgetUtilizationPercentage.round() ?? 0;
    final savingsRate = data?.savingsPercentage.round() ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesignSystemCard(
      glass: true,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.s24),
        decoration: BoxDecoration(
          color: isDark ? null : Colors.white,
          gradient: isDark
              // ignore: deprecated_member_use_from_same_package
              ? AppDesignSystem.primaryGradient.withOpacity(0.1)
              : null,
          border: isDark
              ? null
              : Border.all(
                  color: AppDesignSystem.brandPrimary.withValues(alpha: 0.1),
                ),
          borderRadius: BorderRadius.circular(AppDesignSystem.r24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cash Position',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const VSpace.xs(),
                    Text(
                      _monthLabel(DateTime.now()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppDesignSystem.brandPrimary,
                ),
              ],
            ),
            const VSpace.sm(),
            Text(
              '$_rupee${balance.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const VSpace.sm(),
            Text(
              budgetUtilization == 0
                  ? 'No monthly budget tracked yet'
                  : '$budgetUtilization% of your budget is already used',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const VSpace.xl(),
            Row(
              children: [
                _buildStatItem(
                  'Income',
                  data?.totalIncome ?? 0,
                  AppDesignSystem.success,
                ),
                const HSpace(AppDesignSystem.s32),
                _buildStatItem(
                  'Spent',
                  data?.totalExpenses ?? 0,
                  AppDesignSystem.error,
                ),
              ],
            ),
            const VSpace.lg(),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDesignSystem.r16),
              child: LinearProgressIndicator(
                value: (savingsRate / 100).clamp(0, 1),
                minHeight: 10,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppDesignSystem.brandSecondary,
                ),
              ),
            ),
            const VSpace.sm(),
            Text(
              'Savings rate this month: $savingsRate%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const HSpace.sm(),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Text(
          '$_rupee${amount.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    if (_loadError == null) {
      return const SizedBox.shrink();
    }

    return DesignSystemCard(
      glass: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.s12),
            decoration: BoxDecoration(
              color: AppDesignSystem.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDesignSystem.r12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppDesignSystem.warning,
            ),
          ),
          const HSpace.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard needs attention',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const VSpace.xs(),
                Text(
                  _loadError!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(onPressed: _loadExpenses, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildOverviewGrid() {
    final data = _analyticsData;
    final trends = data?.trends ?? const <TransactionTrend>[];
    final topCategory = _topCategoryEntry(data?.categoryBreakdown);
    final todayNet = trends.isNotEmpty ? trends.last.balance : 0.0;
    final budgetUsed = data?.budgetStatus.budgetUtilizationPercentage ?? 0.0;

    return StreamBuilder<int>(
      stream: _pendingTransactionService.getPendingTransactionCount(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildOverviewCard(
                    title: 'Pending Review',
                    value: pendingCount.toString(),
                    helper: pendingCount == 0
                        ? 'Inbox is clear'
                        : 'Needs confirmation',
                    icon: Icons.inbox_rounded,
                    color: AppDesignSystem.brandPrimary,
                  ),
                ),
                const HSpace.md(),
                Expanded(
                  child: _buildOverviewCard(
                    title: 'Budget Used',
                    value: '${budgetUsed.round()}%',
                    helper: data == null || data.budgetStatus.totalBudget == 0
                        ? 'No budget set'
                        : '$_rupee${data.budgetStatus.remainingBudget.toStringAsFixed(0)} left',
                    icon: Icons.pie_chart_rounded,
                    color: AppDesignSystem.brandAccent,
                  ),
                ),
              ],
            ),
            const VSpace.md(),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewCard(
                    title: 'Today Net',
                    value:
                        '${todayNet >= 0 ? '+' : '-'}$_rupee${todayNet.abs().toStringAsFixed(0)}',
                    helper: 'Net movement today',
                    icon: todayNet >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: todayNet >= 0
                        ? AppDesignSystem.success
                        : AppDesignSystem.error,
                  ),
                ),
                const HSpace.md(),
                Expanded(
                  child: _buildOverviewCard(
                    title: 'Top Category',
                    value: topCategory?.key ?? 'None',
                    helper: topCategory == null
                        ? 'No expense activity yet'
                        : '$_rupee${topCategory.value.toStringAsFixed(0)} this month',
                    icon: Icons.local_offer_rounded,
                    color: AppDesignSystem.brandInfo,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required String helper,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return DesignSystemCard(
      glass: true,
      onTap: onTap,
      padding: const EdgeInsets.all(AppDesignSystem.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDesignSystem.s12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDesignSystem.r12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
            ],
          ),
          const VSpace.md(),
          Text(title, style: theme.textTheme.bodySmall),
          const VSpace.xs(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge,
          ),
          const VSpace.sm(),
          Text(
            helper,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: AppDesignSystem.s12,
      runSpacing: AppDesignSystem.s12,
      children: [
        _buildActionItem(
          icon: Icons.add_rounded,
          label: 'Add',
          description: 'Manual entry',
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) =>
                  ExpenseDialog(onTransactionSaved: _loadExpenses),
            );
          },
        ),
        _buildActionItem(
          icon: Icons.inbox_rounded,
          label: 'Inbox',
          description: 'SMS and alerts',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SmartInboxScreen()),
            );
          },
        ),
        _buildActionItem(
          icon: Icons.payments_rounded,
          label: 'Pay',
          description: 'UPI tools',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScanUPIScreen()),
            );
          },
        ),
        _buildActionItem(
          icon: Icons.auto_awesome_rounded,
          label: 'AI Advice',
          description: 'Forecasts',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AIPredictionsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cardWidth = (MediaQuery.of(context).size.width -
            (AppDesignSystem.s24 * 2) -
            AppDesignSystem.s12) /
        2;

    return SizedBox(
      width: cardWidth,
      child: DesignSystemCard(
        glass: true,
        onTap: onTap,
        padding: const EdgeInsets.all(AppDesignSystem.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesignSystem.s16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDesignSystem.r16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 24),
            ),
            const VSpace.md(),
            Text(label, style: theme.textTheme.titleMedium),
            const VSpace.xs(),
            Text(description, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard() {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final insight = _analyticsData?.insights.isNotEmpty == true
        ? _analyticsData!.insights.first
        : null;
    final topCategory = _topCategoryEntry(_analyticsData?.categoryBreakdown);

    if (insight == null && topCategory == null) {
      return DesignSystemCard(
        glass: true,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesignSystem.s12),
              decoration: BoxDecoration(
                color: AppDesignSystem.brandSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDesignSystem.r12),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppDesignSystem.brandSecondary,
              ),
            ),
            const HSpace.md(),
            Expanded(
              child: Text(
                'Add a few transactions to unlock spending insights and forecasting.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final tone = _insightColor(insight?.type);
    final title = insight?.title ?? 'Spending focus';
    final description = insight?.description ??
        'Most of this month\'s spend is in ${topCategory!.key.toLowerCase()}.';

    return DesignSystemCard(
      glass: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.s12),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDesignSystem.r12),
            ),
            child: Icon(Icons.insights_rounded, color: tone),
          ),
          const HSpace.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const VSpace.xs(),
                Text(description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsHeader() {
    return Text(
      'Recent Activity',
      style: Theme.of(context).textTheme.titleLarge,
    );
  }

  Widget _buildTransactionsList() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_analyticsData == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.s24),
          child: DesignSystemEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Dashboard unavailable',
            message:
                'We could not load your transactions right now. Pull to refresh or retry.',
            action: TextButton(
              onPressed: _loadExpenses,
              child: const Text('Try again'),
            ),
          ),
        ),
      );
    }

    final expenses = [..._analyticsData!.recentExpenses]
      ..sort((a, b) => b.date.compareTo(a.date));
    final openingBalance = _analyticsData?.openingBalance ?? 0.0;
    final showOpening = openingBalance != 0;

    if (expenses.isEmpty && !showOpening) {
      return const SliverToBoxAdapter(
        child: DesignSystemEmptyState(
          icon: Icons.history_rounded,
          title: 'No activity yet',
          message: 'Your recent transactions will appear here.',
        ),
      );
    }

    final displayItemsCount =
        (expenses.length > 5 ? 5 : expenses.length) + (showOpening ? 1 : 0);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.s24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (showOpening && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
              child: PremiumTransactionTile(
                title: 'Balance Carried Forward',
                category: 'Carry Forward',
                amount: openingBalance.abs(),
                date: DateTime(DateTime.now().year, DateTime.now().month, 1),
                isIncome: openingBalance >= 0,
                onTap: () {},
              ),
            );
          }

          final expenseIndex = showOpening ? index - 1 : index;
          final expense = expenses[expenseIndex];

          return Padding(
            padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
            child: PremiumTransactionTile(
              title: expense.title,
              category: expense.category,
              amount: expense.amount,
              date: expense.date,
              isIncome: expense.type == TransactionType.income,
              onTap: () {},
            ),
          );
        }, childCount: displayItemsCount),
      ),
    );
  }
}

extension ColorExtension on LinearGradient {
  LinearGradient withOpacity(double opacity) {
    return LinearGradient(
      colors: colors.map((color) => color.withValues(alpha: opacity)).toList(),
      begin: begin,
      end: end,
    );
  }
}

MapEntry<String, double>? _topCategoryEntry(Map<String, double>? categories) {
  if (categories == null || categories.isEmpty) {
    return null;
  }

  final entries = categories.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.first;
}

Color _insightColor(InsightType? type) {
  switch (type) {
    case InsightType.warning:
      return AppDesignSystem.warning;
    case InsightType.success:
      return AppDesignSystem.success;
    case InsightType.tip:
      return AppDesignSystem.brandInfo;
    case InsightType.info:
    case null:
      return AppDesignSystem.brandPrimary;
  }
}

String _monthLabel(DateTime date) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${months[date.month - 1]} ${date.year}';
}
