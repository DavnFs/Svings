import 'package:flutter/material.dart';

/// App palette, resolved per brightness.
///
/// ponytail: these are static getters rather than `Theme.of(context)` lookups.
/// The screens reference them from ~205 places, many inside private helpers
/// (`_statTile`, `_chip`, `_label`, `_legendItem`, `_buildField`, ...) that
/// receive no BuildContext, so a per-site ColorScheme migration would mean
/// threading context through ~30 builders for an identical result.
///
/// The ceiling: a subtree that locally overrides the theme would not get
/// different colors here. Upgrade path: migrate call sites to
/// `Theme.of(context).colorScheme` role by role, starting with the screens that
/// have a BuildContext in scope.
///
/// [useBrightness] is called once from the app root, before the page tree
/// builds, so every read below is correct for the current frame.
class AppColor {
  AppColor._();

  static Brightness _brightness = Brightness.light;

  /// Called from `MaterialApp.builder` on every rebuild.
  static void useBrightness(Brightness brightness) => _brightness = brightness;

  static bool get _dark => _brightness == Brightness.dark;

  /// Brand dark. Used as a *fill* behind white text (primary buttons, the
  /// today card), so it stays dark in both schemes — it is not the MD3
  /// `primary` role, which is a foreground accent.
  static const primary = Color(0xFF1A1A2E);

  static const _accentLight = Color(0xFF6C63FF);
  static const _accentDark = Color(0xFFA9A2FF);
  static const _surfaceLight = Color(0xFFF8F9FA);
  static const _surfaceDark = Color(0xFF141218);
  static const _cardDark = Color(0xFF211F26);
  static const _borderLight = Color(0xFFE8ECF1);
  static const _borderDark = Color(0xFF49454F);
  static const _textPrimaryLight = Color(0xFF1A1A1A);
  static const _textPrimaryDark = Color(0xFFE6E0E9);
  static const _textSecondaryLight = Color(0xFF6B7280);
  static const _textSecondaryDark = Color(0xFF938F99);
  static const _dangerLight = Color(0xFFDC2626);
  static const _dangerDark = Color(0xFFF2B8B5);
  static const _incomeLight = Color(0xFF059669);
  static const _incomeDark = Color(0xFF7EE2A8);

  static Color get accent => _dark ? _accentDark : _accentLight;
  static Color get surface => _dark ? _surfaceDark : _surfaceLight;
  static Color get card => _dark ? _cardDark : Colors.white;
  static Color get border => _dark ? _borderDark : _borderLight;
  static Color get textPrimary => _dark ? _textPrimaryDark : _textPrimaryLight;
  static Color get textSecondary => _dark ? _textSecondaryDark : _textSecondaryLight;
  static Color get danger => _dark ? _dangerDark : _dangerLight;

  /// Money-in green and money-out red. Brighter in dark mode, where the light
  /// values would sit under the 3:1 floor against a dark surface.
  static Color get income => _dark ? _incomeDark : _incomeLight;
  static Color get outcome => _dark ? _dangerDark : _dangerLight;
}
