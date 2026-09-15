import 'package:flutter/material.dart';

/// App palette, resolved from the live [ColorScheme].
///
/// ponytail: static getters rather than `Theme.of(context)` lookups. The screens
/// reference these from ~205 places, many inside private helpers (`_statTile`,
/// `_chip`, `_label`, `_legendItem`, `_buildField`, ...) that receive no
/// BuildContext, so a per-site migration would mean threading context through
/// ~30 builders for an identical result.
///
/// [useScheme] is called from the app root on every rebuild, before the page
/// tree builds, so every read below is correct for the current frame — including
/// the wallpaper-derived colours `dynamic_color` supplies on Android 12+.
///
/// The ceiling: a subtree that locally overrides the theme would not get
/// different colours here. Upgrade path: migrate call sites to
/// `Theme.of(context).colorScheme` role by role, starting with the screens that
/// already have a BuildContext in scope.
class AppColor {
  AppColor._();

  static ColorScheme? _scheme;
  static Brightness _brightness = Brightness.light;

  /// Called from `MaterialApp.builder` on every rebuild.
  static void useScheme(ColorScheme scheme) {
    _scheme = scheme;
    _brightness = scheme.brightness;
  }

  /// Drops back to the literal fallbacks. Used by tests.
  static void useBrightness(Brightness brightness) {
    _scheme = null;
    _brightness = brightness;
  }

  static bool get _dark => _brightness == Brightness.dark;

  // Literal fallbacks, used only when no scheme has been supplied yet.
  // DESIGN.md strict values.
  static const _accentLight = Color(0xFF7C5CFF);
  static const _accentDark = Color(0xFF9E8CFC);
  static const _surfaceLight = Color(0xFFF8F9FA);
  static const _surfaceDark = Color(0xFF0E0D12);
  static const _cardLight = Color(0xFFFFFFFF);
  static const _cardDark = Color(0xFF1C1B24);
  static const _borderLight = Color(0xFFE5E7EB);
  static const _borderDark = Color(0xFF2B2936);
  static const _textPrimaryLight = Color(0xFF111827);
  static const _textPrimaryDark = Color(0xFFF3F4F6);
  static const _textSecondaryLight = Color(0xFF6B7280);
  static const _textSecondaryDark = Color(0xFF9CA3AF);
  static const _dangerLight = Color(0xFFDC2626);
  static const _dangerDark = Color(0xFFF87171);
  static const _incomeLight = Color(0xFF059669);
  static const _incomeDark = Color(0xFF34D399);

  // Scheme-backed roles carrying dynamic color across call sites.

  static Color get surface => _scheme?.surface ?? (_dark ? _surfaceDark : _surfaceLight);

  /// One tonal step above the surface. MD3 conveys elevation with tonal
  /// surface colour, not shadows.
  static Color get card => _scheme?.surfaceContainerLow ?? (_dark ? _cardDark : _cardLight);

  static Color get border => _scheme?.outlineVariant ?? (_dark ? _borderDark : _borderLight);
  static Color get textPrimary => _scheme?.onSurface ?? (_dark ? _textPrimaryDark : _textPrimaryLight);
  static Color get textSecondary =>
      _scheme?.onSurfaceVariant ?? (_dark ? _textSecondaryDark : _textSecondaryLight);
  static Color get danger => _scheme?.error ?? (_dark ? _dangerDark : _dangerLight);

  /// The brand-ish accent: a tonal derivation of the seed, or the wallpaper's
  /// when dynamic colour is in play.
  static Color get accent => _scheme?.primary ?? (_dark ? _accentDark : _accentLight);

  /// Fill for a primary action.
  static Color get primary => _scheme?.primary ?? const Color(0xFF1A1A2E);

  /// Foreground on [primary]. Always use the pair — hardcoding `Colors.white`
  /// becomes unreadable in dark mode, where `primary` is light.
  static Color get onPrimary => _scheme?.onPrimary ?? Colors.white;

  /// Money-in green and money-out red.
  ///
  /// Deliberately *not* scheme roles. MD3 has no "money in" role, and mapping
  /// income to `tertiary` would make it wallpaper-derived and possibly red,
  /// destroying the one colour distinction this app cannot afford to lose. Tuned
  /// per brightness for contrast instead (DESIGN.md strict values).
  static Color get income => _dark ? _incomeDark : _incomeLight;
  static Color get outcome => _dark ? _dangerDark : _dangerLight;
}
