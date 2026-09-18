import 'package:flutter/material.dart';

/// The app's one theme source, in its own file so tests can build the real
/// theme.
///
/// It used to be a private `_buildTheme` inside `main.dart`, which meant no
/// test — and no screenshot harness — could render the colours the app actually
/// ships: every widget test silently ran on Flutter's M3 default seed
/// (`#6750A4`) instead, so "verified in the dark theme" was never true. Public
/// and importable, the same theme is now one call away for tests.
class AppTheme {
  AppTheme._();

  /// Single seed for both schemes. DESIGN.md strict accent: #7C5CFF light.
  static const seed = Color(0xFF7C5CFF);

  /// Radius scale per DESIGN.md: 10 chips, 14 inputs/buttons, 18 cards/groups,
  /// 24 sheets/modals.
  static const _radiusSmall = 10.0;
  static const _radiusButton = 14.0;
  static const _radiusCard = 18.0;
  static const _radiusSheet = 24.0;

  static RoundedRectangleBorder _rounded(double radius) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  /// [dynamicScheme] is the wallpaper-derived scheme from `dynamic_color`,
  /// present only on Android 12+. Everywhere else the seed is used, so light
  /// and dark stay a matched pair in both cases.
  static ThemeData of(Brightness brightness, {ColorScheme? dynamicScheme}) {
    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      // Ripple needs a visible surface tone to read as a Material layer.
      scaffoldBackgroundColor: scheme.surface,
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        labelSmall: base.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600, letterSpacing: 0.4, fontSize: 11),
      ),
      cardTheme: CardThemeData(shape: _rounded(_radiusCard)),
      dialogTheme: DialogThemeData(shape: _rounded(_radiusSheet)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: _rounded(_radiusButton),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: _rounded(_radiusSmall),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
