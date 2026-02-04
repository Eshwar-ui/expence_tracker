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

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    final authenticated = await _securityService.authenticate();

    if (authenticated) {
      widget.onAuthenticated();
    } else {
      setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppDesignSystem.brandPrimary,
              AppDesignSystem.brandPrimary.withBlue(255),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_person_rounded,
                size: 80,
                color: Colors.white,
              ),
              const VSpace.lg(),
              const Text(
                'Access Locked',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const VSpace.sm(),
              const Text(
                'Please authenticate to continue',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const VSpace.xl(),
              if (!_isAuthenticating)
                PrimaryButton(
                  text: 'Authenticate',
                  onPressed: _authenticate,
                  // Using a specific width or wrapping in a sized box if needed
                ),
              if (_isAuthenticating)
                const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
