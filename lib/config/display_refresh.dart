import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// Android hands a Flutter app a 60Hz surface by default, even on a 90 or 120Hz
/// panel, so every animation is capped at 60fps until the app asks for a faster
/// display mode. On a phone that can do better, that cap is the difference
/// between a spring that reads as fluid and the same spring read at half rate.
///
/// Android only. iOS and the desktop embedders pick their own refresh rate, and
/// the plugin has no implementation there, so this is a no-op.
class DisplayRefresh {
  DisplayRefresh._();

  /// Call once from `main()` before `runApp()`.
  static Future<void> requestHighest() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final supported = await FlutterDisplayMode.supported;
      final active = await FlutterDisplayMode.active;
      await FlutterDisplayMode.setPreferredMode(highest(supported, active));
    } catch (_) {
      // Devices without discrete display modes, and Android below 6.0, throw
      // here. Staying at 60Hz is a fallback, not a failure to report.
    }
  }

  /// The fastest mode that keeps the display's current resolution. Buying hertz
  /// by dropping to a lower resolution would trade a visible win for an
  /// invisible one. Falls back to [active] when nothing matches, which makes
  /// the caller's setPreferredMode a no-op rather than a downgrade.
  ///
  /// Public for tests: a [DisplayMode] list cannot be read on a machine with no
  /// Android display attached.
  @visibleForTesting
  static DisplayMode highest(List<DisplayMode> modes, DisplayMode active) {
    var best = active;
    for (final mode in modes) {
      if (mode.width == active.width &&
          mode.height == active.height &&
          mode.refreshRate > best.refreshRate) {
        best = mode;
      }
    }
    return best;
  }
}
