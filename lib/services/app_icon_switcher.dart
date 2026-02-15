import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppIconSwitcher {
  static const MethodChannel _channel = MethodChannel('app_icon_theme');
  static Brightness? _lastBrightness;

  static Future<void> switchToLight() async {
    if (_lastBrightness == Brightness.light) return;
    try {
      await _channel.invokeMethod('setLightIcon');
      _lastBrightness = Brightness.light;
    } on PlatformException catch (e) {
      debugPrint("Failed to switch to light icon: '${e.message}'.");
    }
  }

  static Future<void> switchToDark() async {
    if (_lastBrightness == Brightness.dark) return;
    try {
      await _channel.invokeMethod('setDarkIcon');
      _lastBrightness = Brightness.dark;
    } on PlatformException catch (e) {
      debugPrint("Failed to switch to dark icon: '${e.message}'.");
    }
  }
}
