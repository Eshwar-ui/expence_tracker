import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/screens/expense_dialog.dart';
import 'package:expence_tracker/screens/home.dart';
import 'package:expence_tracker/screens/transactions_screen.dart';
import 'package:expence_tracker/screens/reports_screen.dart';
import 'package:expence_tracker/screens/profile_screen.dart';
import 'package:expence_tracker/screens/voice_capture_sheet.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
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

  void _openAddExpense({Expense? prefill}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpenseDialog(
        prefill: prefill,
        onTransactionSaved: () {
          // Refresh home if on home tab
          if (_currentIndex == 0) {
            setState(() {});
          }
        },
      ),
    );
  }

  Future<void> _openVoiceQuickAdd() async {
    await HapticFeedback.heavyImpact();
    if (!mounted) return;
    final parsed = await VoiceCaptureSheet.show(context);
    if (!mounted || parsed == null) return;
    _openAddExpense(prefill: parsed);
    showDesignSystemSnackBar(
      context: context,
      message: 'Heard you — review and save.',
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
              // Center split pill: tap "+" for manual add, tap mic for voice
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                child: _AddVoicePill(
                  onAddTap: _openAddExpense,
                  onVoiceTap: _openVoiceQuickAdd,
                ),
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

/// Center bottom-nav action: a gradient pill split into two equal hit areas.
/// Tap the left "+" to open the manual add modal; tap the right mic to start
/// voice quick-add. Each half scales independently on press for tactile feel.
class _AddVoicePill extends StatelessWidget {
  final VoidCallback onAddTap;
  final VoidCallback onVoiceTap;

  const _AddVoicePill({
    required this.onAddTap,
    required this.onVoiceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppDesignSystem.primaryGradient,
        borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.brandPrimary.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _PillHalf(
              icon: Icons.add_rounded,
              iconSize: 26,
              tooltip: 'Add transaction',
              onTap: onAddTap,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDesignSystem.rFull),
                bottomLeft: Radius.circular(AppDesignSystem.rFull),
              ),
            ),
          ),
          // Hairline divider with soft fade on either end.
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Expanded(
            child: _PillHalf(
              icon: Icons.mic_rounded,
              iconSize: 22,
              tooltip: 'Voice quick-add',
              onTap: onVoiceTap,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(AppDesignSystem.rFull),
                bottomRight: Radius.circular(AppDesignSystem.rFull),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillHalf extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _PillHalf({
    required this.icon,
    required this.iconSize,
    required this.tooltip,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_PillHalf> createState() => _PillHalfState();
}

class _PillHalfState extends State<_PillHalf>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 110),
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
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.forward(),
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: ScaleTransition(
            scale: _scale,
            child: Center(
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: widget.iconSize,
              ),
            ),
          ),
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
