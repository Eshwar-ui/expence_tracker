import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../utils/app_design_system.dart';
import '../widgets/design_system_components.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const LockScreen({super.key, required this.onAuthenticated});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final SecurityService _securityService = SecurityService();
  bool _isAuthenticating = false;
  bool _hasAttempted = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    if (!mounted) return;
    setState(() => _isAuthenticating = true);

    bool authenticated = false;
    try {
      authenticated = await _securityService.authenticate();
    } catch (_) {
      authenticated = false;
    }

    if (!mounted) return;
    if (authenticated) {
      widget.onAuthenticated();
    } else {
      setState(() {
        _isAuthenticating = false;
        _hasAttempted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Foreground colors that have enough contrast on either theme's gradient.
    final onGradient = isDark ? Colors.white : theme.colorScheme.onSurface;
    final onGradientMuted = onGradient.withValues(alpha: 0.72);
    final tileFill = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: 0.08);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppDesignSystem.brandPrimary.withValues(alpha: 0.8),
                    AppDesignSystem.darkBg,
                  ]
                : [
                    AppDesignSystem.brandPrimary.withValues(alpha: 0.18),
                    theme.colorScheme.surface,
                  ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      AppDesignSystem.brandAccent.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      AppDesignSystem.brandSecondary.withValues(alpha: 0.1),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: onGradientMuted,
                  ),
                  const VSpace.md(),
                  Text(
                    'EXPENSE TRACKER',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: onGradientMuted,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Semantics(
                    button: true,
                    enabled: !_isAuthenticating,
                    label: _isAuthenticating
                        ? 'Authenticating'
                        : 'Authenticate with biometrics',
                    child: GestureDetector(
                      onTap: _authenticate,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: tileFill,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: onGradient.withValues(alpha: 0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppDesignSystem.brandPrimary
                                  .withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: _isAuthenticating
                            ? CircularProgressIndicator(color: onGradient)
                            : Icon(
                                Icons.fingerprint,
                                size: 50,
                                color: onGradient,
                              ),
                      ),
                    ),
                  ),
                  const VSpace.lg(),
                  Text(
                    _isAuthenticating
                        ? 'Scanning...'
                        : _hasAttempted
                            ? 'Authentication needed to continue'
                            : 'Tap into Finance',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onGradient,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_hasAttempted && !_isAuthenticating) ...[
                    const VSpace.md(),
                    TextButton.icon(
                      onPressed: _authenticate,
                      icon: Icon(Icons.refresh, color: onGradient),
                      label: Text(
                        'Try again',
                        style: TextStyle(color: onGradient),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
