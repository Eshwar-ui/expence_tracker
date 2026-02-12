import 'package:expence_tracker/services/debug_test_notification_service.dart';
import 'package:expence_tracker/services/notification_listener_channel.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DebugTestNotificationScreen extends StatefulWidget {
  const DebugTestNotificationScreen({super.key});

  @override
  State<DebugTestNotificationScreen> createState() =>
      _DebugTestNotificationScreenState();
}

class _DebugTestNotificationScreenState
    extends State<DebugTestNotificationScreen> {
  final _service = DebugTestNotificationService();
  final _notificationChannel = NotificationListenerChannel();

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  String _sourceType = 'Bank';
  int _timestamp = DateTime.now().millisecondsSinceEpoch;

  DebugTestResult? _lastResult;
  bool _isSending = false;
  bool _initialized = false;
  String? _packageName;

  @override
  void initState() {
    super.initState();
    _initDebug();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _initDebug() async {
    if (!kDebugMode) return;
    await _initLocalNotifications();
    _packageName = await _notificationChannel.getAppPackageName();
    final allowed = await _notificationChannel.getAllowedPackages();
    if (_packageName != null && !allowed.contains(_packageName)) {
      final updated = [...allowed, _packageName!];
      await _notificationChannel.setAllowedPackages(updated);
    }
    setState(() => _initialized = true);
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _localNotifications.initialize(settings);
  }

  Future<void> _sendTestNotification() async {
    if (!kDebugMode) return;
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      showDesignSystemSnackBar(
        context: context,
        message: 'Notification body is required',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSending = true;
      _timestamp = DateTime.now().millisecondsSinceEpoch;
    });

    // 1) Trigger a local Android notification for listener testing.
    await _showLocalNotification();

    // 2) Direct parser injection (fail-safe path).
    final result = await _service.runTest(
      sourceType: _sourceType,
      title: _titleController.text.trim(),
      body: body,
      timestamp: _timestamp,
    );

    setState(() {
      _lastResult = result;
      _isSending = false;
    });
  }

  Future<void> _showLocalNotification() async {
    final title = _titleController.text.trim().isEmpty
        ? 'Bank Alert ($_sourceType)'
        : _titleController.text.trim();
    const androidDetails = AndroidNotificationDetails(
      'debug_test_notifications',
      'Debug Test Notifications',
      channelDescription: 'Debug-only test notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      _timestamp % 100000,
      title,
      _bodyController.text.trim(),
      notificationDetails,
    );
  }

  Future<void> _clearDebugData() async {
    await _service.clearDebugEntries();
    setState(() => _lastResult = null);
    showDesignSystemSnackBar(
      context: context,
      message: 'Debug test data cleared',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: const PremiumAppBar(title: 'Debug Test Notification'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesignSystemCard(
              glass: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send Test Notification',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const VSpace.md(),
                  DropdownButtonFormField<String>(
                    value: _sourceType,
                    decoration: const InputDecoration(labelText: 'App source'),
                    items: const [
                      DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      DropdownMenuItem(value: 'Wallet', child: Text('Wallet')),
                    ],
                    onChanged: (value) =>
                        setState(() => _sourceType = value ?? 'Bank'),
                  ),
                  const VSpace.md(),
                  DesignSystemTextField(
                    controller: _titleController,
                    label: 'Notification title (optional)',
                    hint: 'e.g., Transaction Alert',
                    icon: Icons.title_rounded,
                  ),
                  const VSpace.md(),
                  DesignSystemTextField(
                    controller: _bodyController,
                    label: 'Notification body (required)',
                    hint: 'Paste a sample bank/UPI message',
                    icon: Icons.message_rounded,
                  ),
                  const VSpace.md(),
                  Text(
                    'Timestamp: ${DateTime.fromMillisecondsSinceEpoch(_timestamp)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const VSpace.md(),
                  GradientButton(
                    text: _isSending ? 'Sending...' : 'Send Test Notification',
                    onPressed: _isSending || !_initialized
                        ? null
                        : _sendTestNotification,
                  ),
                  const VSpace.sm(),
                  SecondaryButton(
                    text: 'Reset Test Data',
                    onPressed: _clearDebugData,
                  ),
                ],
              ),
            ),
            const VSpace.lg(),
            _buildResultCard(),
            const VSpace.lg(),
            _buildDevInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final theme = Theme.of(context);
    final result = _lastResult;

    if (result == null) {
      return DesignSystemCard(
        glass: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parsing Result', style: theme.textTheme.titleLarge),
            const VSpace.sm(),
            Text('No test run yet.', style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    final parsing = result.parsing;
    final validation = result.validation;

    return DesignSystemCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Parsing Result', style: theme.textTheme.titleLarge),
          const VSpace.sm(),
          Text('Amount: ${parsing.amount ?? '-'}'),
          Text('Type: ${parsing.transactionType ?? '-'}'),
          Text('Merchant: ${parsing.merchant ?? '-'}'),
          Text('Confidence: ${parsing.confidence.toStringAsFixed(2)}'),
          const VSpace.sm(),
          Text(
            validation.isValid ? 'Validation: OK' : 'Validation: Failed',
            style: theme.textTheme.titleSmall?.copyWith(
              color: validation.isValid
                  ? AppDesignSystem.success
                  : AppDesignSystem.error,
            ),
          ),
          if (validation.reasons.isNotEmpty) ...[
            const VSpace.xs(),
            Text('Reasons: ${validation.reasons.join(', ')}'),
          ],
          const VSpace.sm(),
          Text(
            validation.isValid
                ? 'Would create: Test / Debug Entry'
                : 'No expense created',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDevInfo() {
    return DesignSystemCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Debug Info', style: Theme.of(context).textTheme.titleLarge),
          const VSpace.sm(),
          Text('App package: ${_packageName ?? 'unknown'}'),
          const VSpace.xs(),
          const Text(
            'Local notification package cannot be spoofed; direct parser injection uses a mock source.',
          ),
        ],
      ),
    );
  }
}
