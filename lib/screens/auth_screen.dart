import 'package:flutter/material.dart';
import 'package:expence_tracker/services/auth_service.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await _authService.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _isLoading = true);

    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your email address');
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(_emailController.text.trim());
      _showSuccessSnackBar('Password reset email sent!');
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    showDesignSystemSnackBar(
      context: context,
      message: message,
      isError: true,
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    showDesignSystemSnackBar(
      context: context,
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryText =
        isDark ? AppDesignSystem.darkTextMed : AppDesignSystem.textMed;

    return Scaffold(
      body: _AuthBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gutter =
                  constraints.maxWidth < AppDesignSystem.maxContentWidth
                      ? AppDesignSystem.s20
                      : AppDesignSystem.s32;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: gutter,
                  vertical: AppDesignSystem.s24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - AppDesignSystem.s24 * 2)
                        .clamp(0.0, double.infinity),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppDesignSystem.maxContentWidth,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppDesignSystem.r16),
                                child: Image.asset(
                                  isDark
                                      ? 'assets/dark_app_icon.png'
                                      : 'assets/light_app_icon.png',
                                  width:
                                      AppDesignSystem.s48 + AppDesignSystem.s24,
                                  height:
                                      AppDesignSystem.s48 + AppDesignSystem.s24,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            ),
                            const VSpace.md(),
                            Text(
                              'ECTracker',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const VSpace.sm(),
                            Text(
                              _isLogin
                                  ? 'Sign in to your account'
                                  : 'Create your journey',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: secondaryText,
                              ),
                            ),
                            const VSpace.lg(),
                            DesignSystemCard(
                              glass: true,
                              padding: EdgeInsets.zero,
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(AppDesignSystem.s20),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildField(
                                      controller: _emailController,
                                      label: 'Email',
                                      hint: 'example@email.com',
                                      icon: Icons.alternate_email_rounded,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    const VSpace.md(),
                                    _buildField(
                                      controller: _passwordController,
                                      label: 'Password',
                                      hint: 'Your password',
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: _obscurePassword,
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePassword
                                            ? 'Show password'
                                            : 'Hide password',
                                        icon: Icon(_obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),
                                    if (!_isLogin) ...[
                                      const VSpace.md(),
                                      _buildField(
                                        controller: _confirmPasswordController,
                                        label: 'Confirm Password',
                                        hint: 'Repeat password',
                                        icon: Icons.lock_reset_rounded,
                                        obscureText: _obscureConfirmPassword,
                                        suffixIcon: IconButton(
                                          tooltip: _obscureConfirmPassword
                                              ? 'Show confirm password'
                                              : 'Hide confirm password',
                                          icon: Icon(_obscureConfirmPassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined),
                                          onPressed: () => setState(() =>
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword),
                                        ),
                                      ),
                                    ],
                                    if (_isLogin) ...[
                                      const VSpace.xs(),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: isDark
                                                ? AppDesignSystem.authDarkLink
                                                : theme.colorScheme.primary,
                                          ),
                                          onPressed: _handleForgotPassword,
                                          child: const Text('Forgot Password?'),
                                        ),
                                      ),
                                      const VSpace.sm(),
                                    ] else
                                      const VSpace.lg(),
                                    GradientButton(
                                      text: _isLogin
                                          ? 'Sign In'
                                          : 'Create Account',
                                      onPressed:
                                          _isLoading ? null : _handleEmailAuth,
                                      isLoading: _isLoading,
                                    ),
                                    const VSpace.lg(),
                                    Row(
                                      children: [
                                        const Expanded(child: Divider()),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppDesignSystem.s12,
                                          ),
                                          child: Text(
                                            'or continue with',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: secondaryText,
                                            ),
                                          ),
                                        ),
                                        const Expanded(child: Divider()),
                                      ],
                                    ),
                                    const VSpace.md(),
                                    OutlinedButton(
                                      onPressed:
                                          _isLoading ? null : _handleGoogleAuth,
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(
                                          AppDesignSystem.s48 +
                                              AppDesignSystem.s8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppDesignSystem.s16,
                                          vertical: AppDesignSystem.s12,
                                        ),
                                        foregroundColor:
                                            theme.colorScheme.onSurface,
                                        side: BorderSide(
                                          color: isDark
                                              ? AppDesignSystem.darkTextLow
                                              : AppDesignSystem.textLow,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppDesignSystem.r16),
                                        ),
                                        textStyle: theme.textTheme.labelLarge,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SvgPicture.asset(
                                            'assets/google_logo.svg',
                                            width: AppDesignSystem.s24,
                                            height: AppDesignSystem.s24,
                                            excludeFromSemantics: true,
                                          ),
                                          const HSpace.sm(),
                                          const Flexible(
                                            child: Text(
                                              'Google Account',
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const VSpace.md(),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppDesignSystem.s4,
                              children: [
                                Text(
                                  _isLogin
                                      ? "Don't have an account?"
                                      : 'Already have an account?',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: secondaryText,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: isDark
                                        ? AppDesignSystem.authDarkLink
                                        : theme.colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isLogin = !_isLogin;
                                      _passwordController.clear();
                                      _confirmPasswordController.clear();
                                    });
                                  },
                                  child: Text(_isLogin ? 'Sign Up' : 'Sign In'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDesignSystem.r16),
      borderSide: BorderSide(
        color: isDark
            ? AppDesignSystem.darkTextMed.withValues(alpha: 0.35)
            : AppDesignSystem.brandPrimary.withValues(alpha: 0.28),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const VSpace.sm(),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppDesignSystem.darkTextMed
                  : AppDesignSystem.textMed,
            ),
            prefixIcon: Icon(icon, size: AppDesignSystem.s20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark
                ? AppDesignSystem.darkCanvas.withValues(alpha: 0.45)
                : AppDesignSystem.lightCanvas.withValues(alpha: 0.65),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(AppDesignSystem.s16),
          ),
        ),
      ],
    );
  }
}

/// The broad radial lights add depth beneath the frosted form without hard edges.
class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppDesignSystem.authDarkGradient
                : AppDesignSystem.authLightGradient,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.15,
              colors: [
                AppDesignSystem.brandPrimary.withValues(
                  alpha: isDark ? 0.22 : 0.16,
                ),
                AppDesignSystem.brandPrimary.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomLeft,
              radius: 1,
              colors: [
                AppDesignSystem.brandSecondary.withValues(
                  alpha: isDark ? 0.12 : 0.08,
                ),
                AppDesignSystem.brandSecondary.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
