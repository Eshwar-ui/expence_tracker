import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/notification_listener_service.dart';

class AutomaticTrackingSettings extends StatefulWidget {
  const AutomaticTrackingSettings({super.key});

  @override
  State<AutomaticTrackingSettings> createState() =>
      _AutomaticTrackingSettingsState();
}

class _AutomaticTrackingSettingsState extends State<AutomaticTrackingSettings>
    with WidgetsBindingObserver {
  final _service = NotificationListenerService();
  bool _sms = false;
  bool _notifications = false;
  bool _autoSave = false;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final sms = await Permission.sms.isGranted;
      final notifications = await _service.isListenerEnabled();
      final autoSave = await _service.isAutoSaveEnabled();
      if (!mounted) return;
      setState(() {
        _sms = sms;
        _notifications = notifications;
        _autoSave = autoSave;
        _busy = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not check tracking. Tap retry.';
          _busy = false;
        });
      }
    }
  }

  Future<void> _enableSms() async {
    try {
      final status = await Permission.sms.request();
      if (status.isPermanentlyDenied) await openAppSettings();
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not enable SMS. Try again.');
    }
  }

  Future<void> _toggleAutoSave(bool value) async {
    setState(() => _busy = true);
    try {
      await _service.setAutoSaveEnabled(value);
      if (mounted) {
        setState(() {
          _autoSave = value;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save this setting. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const Text(
          'Automatic SMS and payment notification tracking is available on Android.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            _error ??
                ((_sms || _notifications)
                    ? 'Automatic detection is ready'
                    : 'Enable automatic detection'),
            style: Theme.of(context).textTheme.titleSmall),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: Icon(
                  _sms ? Icons.check_circle_outline : Icons.sms_outlined,
                  size: 18),
              label: Text(_sms ? 'SMS enabled' : 'Enable SMS'),
              onPressed: _busy ? null : _enableSms,
            ),
            ActionChip(
              avatar: Icon(
                  _notifications
                      ? Icons.check_circle_outline
                      : Icons.notifications_outlined,
                  size: 18),
              label: Text(
                  _notifications ? 'UPI alerts enabled' : 'Enable UPI alerts'),
              onPressed: _busy
                  ? null
                  : () async {
                      try {
                        await _service.openNotificationSettings();
                      } catch (_) {
                        if (mounted) {
                          setState(() => _error =
                              'Could not open notification settings. Try again.');
                        }
                      }
                    },
            ),
            if (_error != null)
              ActionChip(label: const Text('Retry'), onPressed: _refresh),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-save detected transactions'),
          subtitle: const Text(
              'Save clear payments and income automatically. Others stay in Review. When the app is closed, captured messages are processed when you reopen it.'),
          value: _autoSave,
          onChanged: _busy ? null : _toggleAutoSave,
        ),
      ],
    );
  }
}
