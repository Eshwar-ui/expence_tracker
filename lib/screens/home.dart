import 'dart:async';

import 'package:expence_tracker/models/analytics.dart';
import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/screens/ai_predictions_screen.dart';
import 'package:expence_tracker/screens/scan_upi_screen.dart';
import 'package:expence_tracker/screens/smart_inbox_screen.dart';
import 'package:expence_tracker/services/analytics_service.dart';
import 'package:expence_tracker/services/home_balance_widget_service.dart';
import 'package:expence_tracker/services/pending_transaction_service.dart';
import 'package:expence_tracker/services/recurring_transaction_service.dart';
import 'package:expence_tracker/services/reminder_service.dart';
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
  StreakResult _streak = const StreakResult.empty();
  late final AnimationController _animationController;

  String get _firstName {
    final name = _user?.displayName?.trim();
    if (name == null || name.isEmpty) return 'there';
    return name.split(' ').first;
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Night owl mode 🦉';
    if (hour < 12) return 'Good morning ☀️';
    if (hour < 17) return 'Good afternoon 👋';
    if (hour < 21) return 'Good evening 🌆';
    return 'Good night 🌙';
  }

  String _spendingMood(double budgetUtilization) {
    if (budgetUtilization == 0) return '📊';
    if (budgetUtilization < 50) return '😊';
    if (budgetUtilization < 75) return '😐';
    if (budgetUtilization < 90) return '😬';
    return '🚨';
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

      final streak = await ReminderService().getStreak();

      if (!mounted) return;
      setState(() {
        _analyticsData = data;
        _streak = streak;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          // Single soft top-down gradient — replaces three blurry circles
          // that previously washed every glass card with brand tint.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppDesignSystem.brandPrimary
                        .withValues(alpha: isDark ? 0.12 : 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
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
                          if (_loadError != null) ...[
                            const VSpace.md(),
                            _buildStatusBanner(),
                          ],
                          const VSpace.xl(),
                          const _SectionHeader('Overview'),
                          const VSpace.md(),
                          _buildOverviewRow(),
                          const VSpace.xl(),
                          const _SectionHeader('Quick Actions'),
                          const VSpace.md(),
                          _buildQuickActions(),
                          const VSpace.xl(),
                          const _SectionHeader('Insights'),
                          const VSpace.md(),
                          _buildInsightCard(),
                          const VSpace.xl(),
                          const _SectionHeader('Recent Activity'),
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
                Text(_greeting, style: theme.textTheme.bodyMedium),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _firstName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (_streak.currentStreak >= 1) ...[
                      const HSpace.sm(),
                      _StreakBadge(streak: _streak),
                    ],
                  ],
                ),
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
                      _monthLabel(DateTime.now()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const VSpace.xs(),
                    Text(
                      'Net Balance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.brandPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _spendingMood(budgetUtilization.toDouble()),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ],
            ),
            const VSpace.sm(),
            _AnimatedBalanceCounter(
              balance: balance,
              animationController: _animationController,
            ),
            const VSpace.xs(),
            Text(
              budgetUtilization == 0
                  ? 'Set a budget to track your progress'
                  : budgetUtilization >= 90
                      ? '⚠️ $budgetUtilization% of budget used'
                      : '$budgetUtilization% of budget used — keep it up!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: budgetUtilization >= 90
                    ? AppDesignSystem.error
                    : null,
              ),
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

  Widget _buildOverviewRow() {
    final data = _analyticsData;
    final income = data?.totalIncome ?? 0;
    final spent = data?.totalExpenses ?? 0;

    return StreamBuilder<int>(
      stream: _pendingTransactionService.getPendingTransactionCount(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;
        return Row(
          children: [
            Expanded(
              child: _buildStatTile(
                label: 'Income',
                value: '$_rupee${income.toStringAsFixed(0)}',
                icon: Icons.south_west_rounded,
                color: AppDesignSystem.success,
              ),
            ),
            const HSpace.md(),
            Expanded(
              child: _buildStatTile(
                label: 'Spent',
                value: '$_rupee${spent.toStringAsFixed(0)}',
                icon: Icons.north_east_rounded,
                color: AppDesignSystem.error,
              ),
            ),
            const HSpace.md(),
            Expanded(
              child: _buildStatTile(
                label: 'Pending',
                value: pendingCount.toString(),
                icon: Icons.inbox_rounded,
                color: AppDesignSystem.brandPrimary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return DesignSystemCard(
      glass: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignSystem.s12,
        vertical: AppDesignSystem.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const VSpace.sm(),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const VSpace.xs(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(
        icon: Icons.add_rounded,
        label: 'Add',
        description: 'Manual entry',
        color: AppDesignSystem.brandPrimary,
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ExpenseDialog(onTransactionSaved: _loadExpenses),
        ),
      ),
      _QuickAction(
        icon: Icons.inbox_rounded,
        label: 'Inbox',
        description: 'SMS & alerts',
        color: AppDesignSystem.brandAccent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SmartInboxScreen()),
        ),
      ),
      _QuickAction(
        icon: Icons.qr_code_scanner_rounded,
        label: 'Pay',
        description: 'UPI tools',
        color: AppDesignSystem.brandSecondary,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScanUPIScreen()),
        ),
      ),
      _QuickAction(
        icon: Icons.auto_awesome_rounded,
        label: 'AI Advice',
        description: 'Forecasts',
        color: AppDesignSystem.brandInfo,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AIPredictionsScreen()),
        ),
      ),
    ];

    final cardWidth = (MediaQuery.of(context).size.width -
            (AppDesignSystem.s24 * 2) -
            AppDesignSystem.s12) /
        2;

    return Wrap(
      spacing: AppDesignSystem.s12,
      runSpacing: AppDesignSystem.s12,
      children: actions.map((action) {
        return SizedBox(
          width: cardWidth,
          child: _buildActionItem(action),
        );
      }).toList(),
    );
  }

  Widget _buildActionItem(_QuickAction action) {
    final theme = Theme.of(context);
    return DesignSystemCard(
      glass: true,
      onTap: action.onTap,
      padding: const EdgeInsets.all(AppDesignSystem.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.s12),
            decoration: BoxDecoration(
              color: action.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDesignSystem.r16),
            ),
            child: Icon(action.icon, color: action.color, size: 22),
          ),
          const VSpace.md(),
          Text(action.label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const VSpace.xs(),
          Text(action.description, style: theme.textTheme.bodySmall),
        ],
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });
}

// Animated counter that counts up from 0 to the target balance on load
class _AnimatedBalanceCounter extends StatelessWidget {
  final double balance;
  final AnimationController animationController;

  const _AnimatedBalanceCounter({
    required this.balance,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNegative = balance < 0;
    final color = isNegative ? AppDesignSystem.error : AppDesignSystem.success;

    return AnimatedBuilder(
      animation: CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, _) {
        final progress = CurvedAnimation(
          parent: animationController,
          curve: Curves.easeOutCubic,
        ).value;
        final displayed = balance * progress;
        return Text(
          '$_rupee${displayed.abs().toStringAsFixed(2)}',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            color: isNegative ? color : null,
          ),
        );
      },
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

class _StreakBadge extends StatelessWidget {
  final StreakResult streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPersonalBest = streak.currentStreak > 0 &&
        streak.currentStreak == streak.longestStreak &&
        streak.currentStreak >= 3;

    final tint = isPersonalBest
        ? AppDesignSystem.warning
        : AppDesignSystem.error;

    return Tooltip(
      message: isPersonalBest
          ? 'Personal best — keep it going!'
          : 'Longest: ${streak.longestStreak} days',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
          border: Border.all(color: tint.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              '${streak.currentStreak}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: tint,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
