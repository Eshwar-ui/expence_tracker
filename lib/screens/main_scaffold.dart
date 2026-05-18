import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expence_tracker/screens/expense_dialog.dart';
import 'package:expence_tracker/screens/home.dart';
import 'package:expence_tracker/screens/transactions_screen.dart';
import 'package:expence_tracker/screens/reports_screen.dart';
import 'package:expence_tracker/screens/profile_screen.dart';
import 'package:expence_tracker/services/pending_transaction_service.dart';
import 'package:expence_tracker/utils/app_design_system.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  // Hold the pending-count stream on State so we don't open a fresh Firestore
  // listener every rebuild. Previously the stream was created inline in build().
  late final Stream<int> _pendingCountStream;

  @override
  void initState() {
    super.initState();
    _pendingCountStream =
        PendingTransactionService().getPendingTransactionCount();
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
      stream: _pendingCountStream,
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
              Navigator.pushNamed(context, '/scan');
            },
            icon: Badge(
              label: Text(count.toString()),
              child: const Icon(Icons.notifications_active_rounded),
            ),
            label: const Text('Inbox'),
          ),
        );
      },
    );
  }

  void _openAddExpense() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpenseDialog(
        onTransactionSaved: () {
          // Refresh home if on home tab
          if (_currentIndex == 0) {
            setState(() {});
          }
        },
      ),
    );
  }

  Widget _buildModernBottomNavBar() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              Expanded(
                child: _ModernNavItem(
                  label: 'Home',
                  isActive: _currentIndex == 0,
                  activeIcon: Icons.home_rounded,
                  inactiveIcon: Icons.home_outlined,
                  onTap: () => _onTap(0),
                ),
              ),
              Expanded(
                child: _ModernNavItem(
                  label: 'Transactions',
                  isActive: _currentIndex == 1,
                  activeIcon: Icons.receipt_long_rounded,
                  inactiveIcon: Icons.receipt_long_outlined,
                  onTap: () => _onTap(1),
                ),
              ),
              // Center "+" button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                child: _AddButton(onTap: _openAddExpense),
              ),
              Expanded(
                child: _ModernNavItem(
                  label: 'Reports',
                  isActive: _currentIndex == 2,
                  activeIcon: Icons.analytics_rounded,
                  inactiveIcon: Icons.analytics_outlined,
                  onTap: () => _onTap(2),
                ),
              ),
              Expanded(
                child: _ModernNavItem(
                  label: 'Profile',
                  isActive: _currentIndex == 3,
                  activeIcon: Icons.person_rounded,
                  inactiveIcon: Icons.person_outline_rounded,
                  onTap: () => _onTap(3),
                ),
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

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      value: 1.0,
    );
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppDesignSystem.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppDesignSystem.brandPrimary.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
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
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return Expanded(
      child: Semantics(
        button: true,
        selected: widget.isActive,
        label: widget.label,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? activeColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: widget.isActive
                ? Border.all(color: activeColor.withValues(alpha: 0.3), width: 1)
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
              // FittedBox scales the label down on narrow phones so longer
              // labels ("Transactions") never ellipse.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        widget.isActive ? FontWeight.w700 : FontWeight.w500,
                    color: widget.isActive ? activeColor : inactiveColor,
                  ),
                  child: Text(widget.label, maxLines: 1, softWrap: false),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
