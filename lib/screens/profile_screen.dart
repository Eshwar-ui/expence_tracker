import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:expence_tracker/services/auth_service.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/services/security_service.dart';
import 'package:expence_tracker/models/app_user.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final SecurityService _securityService = SecurityService();
  bool _deviceLockEnabled = false;
  Future<AppUser?>? _userFuture;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
    _loadUserData();
  }

  void _loadUserData() {
    final user = _authService.currentUser;
    if (user != null) {
      _userFuture = _authService.getUserFromFirestore(user.uid);
    }
  }

  Future<void> _loadSecuritySettings() async {
    final enabled = await _securityService.isLockEnabled();
    if (mounted) {
      setState(() => _deviceLockEnabled = enabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const PremiumAppBar(
        title: 'Profile',
        showBackButton: false,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Decorative Gradients (Blurred)
          Positioned(
            top: -100,
            right: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.15),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  // Profile Header Section
                  _buildHeader(user),
                  const VSpace.xl(),

                  // Financial Hub
                  _buildSectionTitle('Financial Hub'),
                  const VSpace.sm(),
                  _buildFinancialHub(),
                  const VSpace.xl(),

                  // Settings & Security
                  _buildSectionTitle('Preferences & Security'),
                  const VSpace.sm(),
                  _buildSettingsSection(),
                  const VSpace.xl(),

                  // Account Actions
                  _buildSectionTitle('Account'),
                  const VSpace.sm(),
                  _buildAccountSection(),
                  const VSpace.xl(),

                  // Logout & Version
                  GradientButton(
                    text: 'Sign Out',
                    onPressed: () => _showLogoutDialog(context),
                    icon: Icons.logout_rounded,
                  ),
                  const VSpace.md(),
                  Text(
                    'Version 2.1.0 (Premium)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const VSpace(120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }

  Widget _buildHeader(User? user) {
    final theme = Theme.of(context);
    final photoURL = user?.photoURL;
    return DesignSystemCard(
      glass: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  backgroundImage:
                      photoURL != null ? NetworkImage(photoURL) : null,
                  child: photoURL == null
                      ? Icon(Icons.person_rounded,
                          size: 50, color: theme.colorScheme.primary)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showEditProfileDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: AppDesignSystem.softShadow(Colors.black),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const VSpace.md(),
          Text(
            user?.displayName ?? 'Welcome Admin',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            user?.email ?? 'no-email@example.com',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const VSpace.md(),
          FutureBuilder<AppUser?>(
            future: _userFuture,
            builder: (context, snapshot) {
              final appUser = snapshot.data;
              if (appUser != null) {
                final date = DateFormat('MMMM yyyy').format(appUser.createdAt);
                return DesignSystemBadge(
                  text: 'Gold Member since $date',
                  color: AppDesignSystem.brandAccent,
                );
              }
              return const DesignSystemBadge(
                text: 'Premium Member',
                color: AppDesignSystem.brandPrimary,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialHub() {
    return DesignSystemCard(
      glass: true,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Budget Planner',
            subtitle: 'Set and track spending limits',
            onTap: () => Navigator.pushNamed(context, '/budget'),
          ),
          _divider(),
          _buildActionTile(
            icon: Icons.repeat_rounded,
            title: 'Recurring Payments',
            subtitle: 'Manage subscriptions & bills',
            onTap: () => Navigator.pushNamed(context, '/recurring'),
          ),
          _divider(),
          _buildActionTile(
            icon: Icons.category_rounded,
            title: 'Categories',
            subtitle: 'Customise your labels',
            onTap: () => Navigator.pushNamed(context, '/categories'),
          ),
          _divider(),
          _buildActionTile(
            icon: Icons.bar_chart_rounded,
            title: 'Detailed Reports',
            subtitle: 'Analytics and trends',
            onTap: () => Navigator.pushNamed(context, '/reports'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return DesignSystemCard(
      glass: true,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.notifications_active_rounded,
            title: 'Notifications',
            subtitle: 'Alerts and reminders',
            onTap: () => _showNotificationsDialog(context),
          ),
          _divider(),
          _buildActionTile(
            icon: Icons.security_rounded,
            title: 'Security',
            subtitle: 'Biometrics and PIN',
            onTap: () => _showSecurityDialog(context),
          ),
          _divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _iconBox(Icons.fingerprint_rounded, Colors.orange),
                const HSpace.md(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('App Lock',
                          style: Theme.of(context).textTheme.titleSmall),
                      Text('Secure with device lock',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _deviceLockEnabled,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (value) async {
                    final canAuth = await _securityService.canAuthenticate();
                    if (canAuth) {
                      await _securityService.setLockEnabled(value);
                      setState(() => _deviceLockEnabled = value);
                    } else {
                      if (context.mounted) {
                        showDesignSystemSnackBar(
                          context: context,
                          message: 'Biometrics not available',
                          isError: true,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return DesignSystemCard(
      glass: true,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.info_outline_rounded,
            title: 'About the App',
            subtitle: 'Terms, Privacy & Version',
            onTap: () => _showAboutDialog(context),
          ),
          _divider(),
          _buildActionTile(
            icon: Icons.delete_forever_rounded,
            title: 'Delete Account',
            subtitle: 'Permanently remove your data',
            titleColor: AppDesignSystem.error,
            iconColor: AppDesignSystem.error,
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      onTap: onTap,
      leading: _iconBox(icon, iconColor),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.bold,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    );
  }

  Widget _iconBox(IconData icon, Color? color) {
    final theme = Theme.of(context);
    final iconCol = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconCol.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconCol, size: 22),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      indent: 64,
      endIndent: 16,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDesignSystemDialog(
      context: context,
      title: 'Sign Out',
      message: 'Ready to take a break? We\'ll keep your data safe.',
      confirmLabel: 'Sign Out',
      onConfirm: () async {
        try {
          await AuthService().signOut();
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/auth');
          }
        } catch (e) {
          if (context.mounted) {
            showDesignSystemSnackBar(
                context: context, message: 'Error: $e', isError: true);
          }
        }
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDesignSystemDialog(
      context: context,
      title: 'Delete Account',
      message:
          'This is permanent. All your financial history will be wiped out. Continue?',
      confirmLabel: 'Delete Forever',
      destructive: true,
      onConfirm: () async {
        try {
          await AuthService().deleteAccount();
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/auth');
          }
        } catch (e) {
          if (context.mounted) {
            showDesignSystemSnackBar(
                context: context, message: 'Action failed: $e', isError: true);
          }
        }
      },
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final user = AuthService().currentUser;
    final nameController = TextEditingController(text: user?.displayName);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: DesignSystemCard(
              glass: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Edit Profile',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const VSpace.lg(),
                  DesignSystemTextField(
                    controller: nameController,
                    label: 'Display Name',
                    hint: 'Enter your name',
                    icon: Icons.person_outline_rounded,
                  ),
                  const VSpace.xl(),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          text: 'Discard',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const HSpace.md(),
                      Expanded(
                        child: GradientButton(
                          text: 'Update',
                          isLoading: isSaving,
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setDialogState(() => isSaving = true);
                                  try {
                                    await AuthService().updateUserProfile(
                                      displayName: nameController.text.trim(),
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      setState(() {});
                                      showDesignSystemSnackBar(
                                          context: context,
                                          message: 'Profile updated!');
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      setDialogState(() => isSaving = false);
                                      showDesignSystemSnackBar(
                                          context: context,
                                          message: 'Failed: $e',
                                          isError: true);
                                    }
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
      ),
    );
  }

  void _showSecurityDialog(BuildContext context) async {
    final canAuth = await _securityService.canAuthenticate();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: DesignSystemCard(
            glass: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security_rounded,
                    size: 48, color: AppDesignSystem.brandPrimary),
                const VSpace.md(),
                Text('Security Settings',
                    style: Theme.of(context).textTheme.titleLarge),
                const VSpace.md(),
                Text(
                  'Your data is encrypted and secured by Google Cloud and device-level biometrics.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const VSpace.lg(),
                _buildSwitchTile(
                  'Biometric Authentication',
                  canAuth ? 'Use FaceID/Fingerprint' : 'Not supported',
                  _deviceLockEnabled,
                  canAuth
                      ? (val) {
                          _securityService.setLockEnabled(val);
                          setState(() => _deviceLockEnabled = val);
                        }
                      : null,
                ),
                const VSpace.lg(),
                GradientButton(
                  text: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    bool daily = true;
    bool trans = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: DesignSystemCard(
              glass: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Preferences',
                      style: Theme.of(context).textTheme.titleLarge),
                  const VSpace.md(),
                  _buildSwitchTile('Daily Reminders', 'Log your expenses daily',
                      daily, (v) => setDialogState(() => daily = v)),
                  _buildSwitchTile('Smart Detection', 'Auto-detect from SMS',
                      trans, (v) => setDialogState(() => trans = v)),
                  const VSpace.lg(),
                  GradientButton(
                      text: 'Save Changes',
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AboutDialog(
          applicationName: 'Expense Pro',
          applicationVersion: '2.1.0',
          applicationIcon: const Icon(Icons.auto_graph_rounded,
              color: AppDesignSystem.brandPrimary, size: 40),
          children: [
            const VSpace.md(),
            const Text(
                'A premium financial management tool built for high-performance individuals.'),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value,
      ValueChanged<bool>? onChanged) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: Switch.adaptive(
          value: value,
          activeColor: AppDesignSystem.brandPrimary,
          onChanged: onChanged),
      contentPadding: EdgeInsets.zero,
    );
  }
}
