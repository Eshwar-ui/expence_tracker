import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

enum WidgetExpenseAction {
  add,
  voice,
  food,
  travel,
  shopping;

  static WidgetExpenseAction? fromUri(Uri? uri) {
    if (uri == null ||
        uri.scheme != 'expense-widget' ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    for (final action in values) {
      if (action.name == uri.host) return action;
    }
    return null;
  }

  String? get category => switch (this) {
        food => 'Food',
        travel => 'Transportation',
        shopping => 'Shopping',
        _ => null,
      };
}

/// Capture widget taps early, but consume them only in the authenticated UI.
class WidgetQuickAddService {
  WidgetQuickAddService._();
  static final instance = WidgetQuickAddService._();
  final pending = ValueNotifier<WidgetExpenseAction?>(null);
  StreamSubscription<Uri?>? _subscription;

  Future<void> initialize() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _subscription != null) {
      return;
    }
    _subscription = HomeWidget.widgetClicked.listen((uri) {
      final action = WidgetExpenseAction.fromUri(uri);
      if (action != null) pending.value = action;
    }, onError: (Object error) {
      debugPrint('Widget click listener: $error');
    });
    try {
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      final action = WidgetExpenseAction.fromUri(initial);
      if (pending.value == null && action != null) pending.value = action;
    } catch (error) {
      debugPrint('Widget launch check: $error');
    }
  }

  WidgetExpenseAction? take() {
    final action = pending.value;
    pending.value = null;
    return action;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  static Future<bool> pin({required bool shortcuts}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
    await HomeWidget.requestPinWidget(
        qualifiedAndroidName:
            'com.eshwar.expensetracker.${shortcuts ? 'ExpenseShortcutsWidgetProvider' : 'QuickExpenseWidgetProvider'}');
    return true;
  }
}
