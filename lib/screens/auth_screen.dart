import 'dart:ui';
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

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient decoration
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        AppDesignSystem.brandPrimary.withValues(alpha: 0.1),
                        Colors.black
                      ]
                    : [
                        AppDesignSystem.brandPrimary.withValues(alpha: 0.05),
                        Colors.white
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Decorative Circles with Blur
          Positioned(
            top: -100,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppDesignSystem.brandPrimary.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -50,
            left: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppDesignSystem.brandSecondary.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo and Title
                      TweenAnimationBuilder<double>(
                        duration: const Duration(seconds: 1),
                        tween: Tween(begin: 0, end: 1),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: AppDesignSystem.primaryGradient,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: AppDesignSystem.softShadow(
                                  AppDesignSystem.brandPrimary,
                                ),
                              ),
                              child: Image.asset(
                                isDark
                                    ? 'assets/dark_app_icon.png'
                                    : 'assets/light_app_icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            // const VSpace.sm(),
                            // Row(
                            //   mainAxisAlignment: MainAxisAlignment.center,
                            //   children: [
                            //     _buildIconChip('assets/light_app_icon.png'),
                            //     const HSpace.sm(),
                            //     _buildIconChip('assets/dark_app_icon.png'),
                            //   ],
                            // ),
                            const VSpace.lg(),
                            Text(
                              'ECTracker',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                                color: isDark
                                    ? Colors.white
                                    : AppDesignSystem.brandPrimary,
                              ),
                            ),
                            const VSpace.xs(),
                            Text(
                              _isLogin
                                  ? 'Sign in to your account'
                                  : 'Create your journey',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const VSpace.xl(),

                      // Form Card
                      DesignSystemCard(
                        padding: const EdgeInsets.all(24),
                        glass: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DesignSystemTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'example@email.com',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const VSpace.md(),
                            DesignSystemTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            if (!_isLogin) ...[
                              const VSpace.md(),
                              DesignSystemTextField(
                                controller: _confirmPasswordController,
                                label: 'Confirm Password',
                                hint: '••••••••',
                                icon: Icons.lock_reset_rounded,
                                obscureText: _obscureConfirmPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword),
                                ),
                              ),
                            ],
                            if (_isLogin)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _handleForgotPassword,
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            const VSpace.lg(),
                            GradientButton(
                              text: _isLogin ? 'Sign In' : 'Create Account',
                              onPressed: _isLoading ? null : _handleEmailAuth,
                              isLoading: _isLoading,
                            ),
                          ],
                        ),
                      ),

                      const VSpace.lg(),

                      // Social Sign In
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR CONTINUE WITH',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),

                      const VSpace.lg(),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _handleGoogleAuth,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppDesignSystem.r16),
                            ),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/google_logo.svg',
                                height: 24,
                              ),
                              const HSpace.md(),
                              const Text(
                                'Google Account',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const VSpace.xl(),

                      // Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLogin
                                ? "Don't have an account?"
                                : "Already have an account?",
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                                _passwordController.clear();
                                _confirmPasswordController.clear();
                              });
                            },
                            child: Text(
                              _isLogin ? 'Sign Up' : 'Sign In',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
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
        ],
      ),
    );
  }
}
