import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Hides screens that show a donor's health data from screenshots, screen
/// recordings and the app-switcher preview (FLAG_SECURE on Android; a blur
/// over the app-switcher snapshot plus screenshot blocking on iOS).
///
/// Call [protect] in initState and [unprotect] in dispose of a sensitive
/// screen. Platforms the plugin doesn't support (macOS, web) just carry on
/// unprotected rather than crashing the screen.
class ScreenPrivacy {
  static Future<void> protect() async {
    try {
      await ScreenProtector.preventScreenshotOn();
      await ScreenProtector.protectDataLeakageWithBlur();
    } catch (e) {
      debugPrint('ScreenPrivacy.protect unavailable: $e');
    }
  }

  static Future<void> unprotect() async {
    try {
      await ScreenProtector.preventScreenshotOff();
      await ScreenProtector.protectDataLeakageWithBlurOff();
    } catch (e) {
      debugPrint('ScreenPrivacy.unprotect unavailable: $e');
    }
  }
}
