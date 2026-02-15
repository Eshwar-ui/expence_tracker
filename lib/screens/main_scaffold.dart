import 'package:flutter/material.dart';
import 'package:expence_tracker/screens/home.dart';
import 'package:expence_tracker/screens/transactions_screen.dart';
import 'package:expence_tracker/screens/reports_screen.dart';
import 'package:expence_tracker/screens/profile_screen.dart';
import 'package:expence_tracker/screens/pending_transactions_screen.dart';
import 'package:expence_tracker/services/pending_transaction_service.dart';
import 'package:expence_tracker/services/notification_service.dart';
import 'package:expence_tracker/services/firestore_service.dart';
import 'package:expence_tracker/models/pending_transaction.dart';
import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'dart:async';
import 'dart:ui';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  StreamSubscription<PendingTransaction>? _transactionSubscription;

  @override
  void initState() {
    super.initState();
    _initTransactionListener();
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    super.dispose();
  }

  void _initTransactionListener() {
    _transactionSubscription =
        NotificationService().detectedTransactionStream.listen((transaction) {
      if (mounted) {
        _showTransactionPopup(transaction);
      }
    });
  }

  void _showTransactionPopup(PendingTransaction transaction) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: DesignSystemCard(
            glass: true,
            padding: const EdgeInsets.all(AppDesignSystem.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.brandPrimary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppDesignSystem.brandPrimary,
                    size: 40,
                  ),
                ),
                const VSpace.md(),
                Text(
                  'Transaction Detected',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  textAlign: TextAlign.center,
                ),
                const VSpace.sm(),
                Text(
                  'We detected a potential expense from ${transaction.appName}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                const VSpace.lg(),
                DesignSystemCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.merchantName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Via ${transaction.appName}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const HSpace.md(),
                      Text(
                        '₹${transaction.amount.toStringAsFixed(2)}',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppDesignSystem.brandPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ],
                  ),
                ),
                const VSpace.xl(),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        text: 'Discard',
                        onPressed: () async {
                          await PendingTransactionService()
                              .deletePendingTransaction(transaction.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ),
                    const HSpace.md(),
                    Expanded(
                      child: GradientButton(
                        text: 'Add Entry',
                        onPressed: () async {
                          final expense = Expense(
                            id: transaction.id,
                            title: transaction.merchantName,
                            amount: transaction.amount,
                            date: transaction.detectedAt,
                            category: transaction.suggestedCategory ?? 'Other',
                            description: 'Auto-detected via notification',
                            type: TransactionType.expense,
                            paymentMethod: transaction.appName,
                          );

                          await FirestoreService().addExpense(expense);
                          await PendingTransactionService()
                              .deletePendingTransaction(transaction.id);

                          if (context.mounted) {
                            Navigator.pop(context);
                            showDesignSystemSnackBar(
                              context: context,
                              message: 'Expense added successfully',
                              icon: Icons.check_circle_rounded,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final List<Widget> _pages = const [
    HomeScreen(),
    TransactionsScreen(),
    ReportsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
        child: Stack(
          children: [
            _pages[_currentIndex],
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildModernBottomNavBar(),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildPendingTransactionsFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      // bottomNavigationBar: _buildModernBottomNavBar(),
    );
  }

  Widget _buildPendingTransactionsFAB() {
    return StreamBuilder<int>(
      stream: PendingTransactionService().getPendingTransactionCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        if (count == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(top: 50, right: 8),
          child: FloatingActionButton.extended(
            backgroundColor: AppDesignSystem.brandPrimary,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PendingTransactionsScreen(),
                ),
              );
            },
            icon: Badge(
              label: Text(count.toString()),
              child: const Icon(Icons.notifications_active_rounded),
            ),
            label: const Text('Review'),
          ),
        );
      },
    );
  }

  Widget _buildModernBottomNavBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ModernNavItem(
                label: 'Dashboard',
                isActive: _currentIndex == 0,
                activeIcon: Icons.dashboard_rounded,
                inactiveIcon: Icons.dashboard_outlined,
                onTap: () => _onTap(0),
              ),
              _ModernNavItem(
                label: 'Transactions',
                isActive: _currentIndex == 1,
                activeIcon: Icons.swap_horiz_rounded,
                inactiveIcon: Icons.swap_horiz_outlined,
                onTap: () => _onTap(1),
              ),
              _ModernNavItem(
                label: 'Reports',
                isActive: _currentIndex == 2,
                activeIcon: Icons.analytics_rounded,
                inactiveIcon: Icons.analytics_outlined,
                onTap: () => _onTap(2),
              ),
              _ModernNavItem(
                label: 'Profile',
                isActive: _currentIndex == 3,
                activeIcon: Icons.person_rounded,
                inactiveIcon: Icons.person_outline_rounded,
                onTap: () => _onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }
}

class _ModernNavItem extends StatefulWidget {
  final String label;
  final bool isActive;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final VoidCallback onTap;

  const _ModernNavItem({
    required this.label,
    required this.isActive,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.onTap,
  });

  @override
  State<_ModernNavItem> createState() => _ModernNavItemState();
}

class _ModernNavItemState extends State<_ModernNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_ModernNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color activeColor = Theme.of(context).colorScheme.primary;
    final Color inactiveColor = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.6);

    return Expanded(
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? activeColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: widget.isActive
                ? Border.all(color: activeColor.withOpacity(0.3), width: 1)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: widget.isActive ? _scaleAnimation.value : 1.0,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        widget.isActive
                            ? widget.activeIcon
                            : widget.inactiveIcon,
                        key: ValueKey<bool>(widget.isActive),
                        color: widget.isActive ? activeColor : inactiveColor,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      widget.isActive ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isActive ? activeColor : inactiveColor,
                ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
