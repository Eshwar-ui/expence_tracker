import 'dart:ui';
import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/models/analytics.dart';

import 'package:expence_tracker/screens/scan_upi_screen.dart';
import 'package:expence_tracker/services/analytics_service.dart';
import 'package:expence_tracker/services/recurring_transaction_service.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/app_design_system.dart';
import 'expense_dialog.dart';
import 'ai_predictions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  AnalyticsData? _analyticsData;
  bool _isLoading = true;
  late AnimationController _animationController;

  final AnalyticsService _analyticsService = AnalyticsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  String get _firstName {
    final name = _user?.displayName?.trim();
    if (name == null || name.isEmpty) return 'User';
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
    setState(() => _isLoading = true);
    try {
      // Execute recurring transactions first (don't let it block data loading)
      try {
        await RecurringTransactionService().executeDueTransactions();
      } catch (_) {
        // Ignore recurring transaction errors - they shouldn't block data loading
      }

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end = now;

      final data = await _analyticsService.getAnalyticsData(
        startDate: start,
        endDate: end,
      );

      if (!mounted) return;
      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Orbits
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppDesignSystem.brandPrimary.withOpacity(0.25),
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
                color: AppDesignSystem.brandSecondary.withOpacity(0.2),
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
                color: AppDesignSystem.brandAccent.withOpacity(0.15),
              ),
            ),
          ),

          // Ambient Blur Layer for Mesh Gradient Effect
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
                          _buildQuickActions(),
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
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
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
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppDesignSystem.r24),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final balance = _analyticsData?.balance ?? 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesignSystemCard(
      glass: true,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.s24),
        decoration: BoxDecoration(
          color: isDark ? null : Colors.white,
          gradient:
              isDark ? AppDesignSystem.primaryGradient.withOpacity(0.1) : null,
          border: isDark
              ? null
              : Border.all(
                  color: AppDesignSystem.brandPrimary.withOpacity(0.1),
                ),
          borderRadius: BorderRadius.circular(AppDesignSystem.r24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Balance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppDesignSystem.brandPrimary,
                ),
              ],
            ),
            const VSpace.sm(),
            Text(
              '₹${balance.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const VSpace.xl(),
            Row(
              children: [
                _buildStatItem(
                  'Income',
                  _analyticsData?.totalIncome ?? 0,
                  AppDesignSystem.success,
                ),
                const HSpace(AppDesignSystem.s32),
                _buildStatItem(
                  'Spent',
                  _analyticsData?.totalExpenses ?? 0,
                  AppDesignSystem.error,
                ),
              ],
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
          '₹${amount.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionItem(Icons.add_rounded, 'Add', () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) =>
                ExpenseDialog(onTransactionSaved: _loadExpenses),
          );
        }),
        _buildActionItem(Icons.payments_rounded, 'Pay', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScanUPIScreen()),
          );
        }),
        _buildActionItem(Icons.auto_awesome_rounded, 'AI Advice', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AIPredictionsScreen(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDesignSystem.r16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.s16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppDesignSystem.r16),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.1),
              ),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 28),
          ),
          const VSpace.sm(),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/transactions'),
          child: const Text('View All'),
        ),
      ],
    );
  }

  Widget _buildTransactionsList() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final expenses = _analyticsData?.recentExpenses ?? [];
    final openingBalance = _analyticsData?.openingBalance ?? 0.0;

    // Create a virtual transaction for opening balance if info exists
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
          final e = expenses[expenseIndex];

          return Padding(
            padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
            child: PremiumTransactionTile(
              title: e.title,
              category: e.category,
              amount: e.amount,
              date: e.date,
              isIncome: e.type == TransactionType.income,
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
      colors: colors.map((c) => c.withOpacity(opacity)).toList(),
      begin: begin,
      end: end,
    );
  }
}
