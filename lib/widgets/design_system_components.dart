import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/app_design_system.dart';

/// Reusable Modern Design System Components
/// Refined for Marketplace-level Experience.

// ============================================================================
// BUTTONS - PREMIUM GRADIENTS
// ============================================================================

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final LinearGradient? gradient;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? null
            : (gradient ?? AppDesignSystem.primaryGradient),
        borderRadius: BorderRadius.circular(AppDesignSystem.r16),
        color: onPressed == null ? theme.disabledColor : null,
        boxShadow: onPressed == null
            ? null
            : AppDesignSystem.softShadow(theme.primaryColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppDesignSystem.r16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: theme.colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.r16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(text, style: theme.textTheme.labelLarge),
      ),
    );
  }
}

// ============================================================================
// CARDS - GLASSMORPHISM & PRECISE DEPTH
// ============================================================================

class DesignSystemCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool glass;

  const DesignSystemCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.glass = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: glass
            ? (isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white.withOpacity(0.6))
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppDesignSystem.r24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppDesignSystem.s24),
            child: child,
          ),
        ),
      ),
    );

    if (glass) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppDesignSystem.r24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: card,
        ),
      );
    }

    return card;
  }
}

// ============================================================================
// APP BARS - PREMIUM GLASSMOPHISM
// ============================================================================

class PremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackTap;
  final bool centerTitle;

  const PremiumAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.onBackTap,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AppBar(
          title: Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: centerTitle,
          backgroundColor: isDark
              ? Colors.black.withOpacity(0.1)
              : Colors.white.withOpacity(0.3),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: showBackButton && Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: onBackTap ?? () => Navigator.pop(context),
                )
              : null,
          actions: [
            if (actions != null) ...actions!,
            const SizedBox(width: AppDesignSystem.s8),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ============================================================================
// LIST ITEMS - DASHBOARD STYLE
// ============================================================================

class PremiumTransactionTile extends StatelessWidget {
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final bool isIncome;
  final VoidCallback? onTap;

  const PremiumTransactionTile({
    super.key,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.isIncome,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DesignSystemCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignSystem.s16,
        vertical: AppDesignSystem.s12,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.s12),
            decoration: BoxDecoration(
              color:
                  (isIncome ? AppDesignSystem.success : AppDesignSystem.error)
                      .withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDesignSystem.r12),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? AppDesignSystem.success : AppDesignSystem.error,
              size: 20,
            ),
          ),
          const SizedBox(width: AppDesignSystem.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(category, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? "+" : "-"}₹${amount.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isIncome
                      ? AppDesignSystem.success
                      : AppDesignSystem.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                "${date.day}/${date.month}",
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BADGES
// ============================================================================

class DesignSystemBadge extends StatelessWidget {
  final String text;
  final Color color;

  const DesignSystemBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================================================
// SPACERS
// ============================================================================

class VSpace extends StatelessWidget {
  final double size;
  const VSpace(this.size, {super.key});
  const VSpace.sm({super.key}) : size = AppDesignSystem.s8;
  const VSpace.md({super.key}) : size = AppDesignSystem.s16;
  const VSpace.lg({super.key}) : size = AppDesignSystem.s24;
  const VSpace.xl({super.key}) : size = AppDesignSystem.s32;
  @override
  Widget build(BuildContext context) => SizedBox(height: size);
}

class HSpace extends StatelessWidget {
  final double size;
  const HSpace(this.size, {super.key});
  const HSpace.sm({super.key}) : size = AppDesignSystem.s8;
  const HSpace.md({super.key}) : size = AppDesignSystem.s16;
  @override
  Widget build(BuildContext context) => SizedBox(width: size);
}

// ============================================================================
// LOADING & EMPTY
// ============================================================================

class DesignSystemLoading extends StatelessWidget {
  const DesignSystemLoading({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 3));
  }
}

class DesignSystemEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const DesignSystemEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppDesignSystem.s32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: theme.colorScheme.outline),
          const VSpace.lg(),
          Text(
            title,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const VSpace.sm(),
            Text(
              message!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const VSpace.xl(), action!],
        ],
      ),
    );
  }
}

// ============================================================================
// INPUTS - MODERN & CLEAN
// ============================================================================

class DesignSystemTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;

  const DesignSystemTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.onChanged,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(AppDesignSystem.r16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : theme.colorScheme.primary.withOpacity(0.1),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            onChanged: onChanged,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              prefixIcon: icon != null
                  ? Icon(icon, size: 20, color: theme.colorScheme.primary)
                  : null,
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// DIALOGS - GLASSMORPHIC ALERTS
// ============================================================================

Future<T?> showDesignSystemDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  required VoidCallback onConfirm,
}) {
  return showDialog<T>(
    context: context,
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
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const VSpace.md(),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const VSpace.xl(),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      text: cancelLabel ?? 'Cancel',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const HSpace.md(),
                  Expanded(
                    child: GradientButton(
                      text: confirmLabel ?? 'Confirm',
                      gradient: destructive
                          ? AppDesignSystem.errorGradient
                          : null,
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
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

// FOR COMPATIBILITY
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  PrimaryButton({required this.text, this.onPressed, this.isLoading = false});
  @override
  Widget build(BuildContext context) =>
      GradientButton(text: text, onPressed: onPressed, isLoading: isLoading);
}
