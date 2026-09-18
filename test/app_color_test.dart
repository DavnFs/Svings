import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_theme.dart';

/// The palette adapts to brightness at runtime, which is only correct if
/// `MaterialApp.builder` sets it before the page tree builds.
void main() {
  tearDown(() => AppColor.useBrightness(Brightness.light));

  // These two groups matter as a pair: the first pins the literals used before a
  // scheme is supplied, the second runs the same roles through the theme the app
  // really builds. Until AppTheme was extracted, only the literals were ever
  // tested — widget tests pumped a bare MaterialApp and got Flutter's default
  // seed (#6750A4) instead of the app's #7C5CFF, so "verified in dark mode"
  // covered a palette the app does not ship.
  group('literal fallbacks (no scheme supplied yet)', () {

  test('defaults to the light palette', () {
    expect(AppColor.surface, const Color(0xFFF8F9FA));
    expect(AppColor.card, Colors.white);
    expect(AppColor.textPrimary, const Color(0xFF111827));
  });

  test('switches surfaces and text for dark', () {
    AppColor.useBrightness(Brightness.dark);
    expect(AppColor.surface, const Color(0xFF0E0D12));
    expect(AppColor.card, const Color(0xFF1C1B24));
    expect(AppColor.textPrimary, const Color(0xFFF3F4F6));
  });

  test('primary stays dark in both schemes', () {
    // It is a fill behind white text (buttons, the today card). If it ever
    // lightens in dark mode, white-on-primary becomes unreadable.
    final light = AppColor.primary;
    AppColor.useBrightness(Brightness.dark);
    expect(AppColor.primary, light);
    expect(
      AppColor.primary.computeLuminance(),
      lessThan(0.1),
      reason: 'primary must stay dark enough for white text',
    );
  });

  test('border is never reused as a foreground color', () {
    // The chevron icon used to be AppColor.border, ~1.19:1 on white.
    for (final brightness in Brightness.values) {
      AppColor.useBrightness(brightness);
      final ratio = _contrast(AppColor.textSecondary, AppColor.surface);
      expect(ratio, greaterThan(4.5), reason: 'textSecondary on surface, $brightness');
      expect(AppColor.textSecondary, isNot(AppColor.border));
    }
  });
  });

  // The palette the app actually renders: the real seed through the real theme
  // builder, with AppColor switched onto that scheme the way MaterialApp.builder
  // does it on every frame.
  group('the shipped scheme', () {
    for (final brightness in Brightness.values) {
      test('${brightness.name}: text roles clear AA on every surface they sit on', () {
        final scheme = AppTheme.of(brightness).colorScheme;
        AppColor.useScheme(scheme);
        final surfaces = <String, Color>{
          'surface': AppColor.surface,
          'card/surfaceContainerLow': AppColor.card,
          'surfaceContainerHigh': scheme.surfaceContainerHigh,
          'surfaceContainerHighest': scheme.surfaceContainerHighest,
        };
        for (final s in surfaces.entries) {
          for (final fg in <String, Color>{
            'textPrimary': AppColor.textPrimary,
            'textSecondary': AppColor.textSecondary,
          }.entries) {
            final ratio = AppColor.contrastRatio(fg.value, s.value);
            expect(ratio, greaterThanOrEqualTo(4.5),
                reason: '${fg.key} on ${s.key}, $brightness, got ${ratio.toStringAsFixed(2)}');
          }
        }
      });

      test('${brightness.name}: the snackbar fills clear AA against their own text', () {
        final scheme = AppTheme.of(brightness).colorScheme;
        AppColor.useScheme(scheme);
        // income/outcome are fills, not text colours: nothing in the app paints
        // them as a foreground. Over the green, Material's default snackbar text
        // (onInverseSurface) measured 3.4:1 — the fill has to choose its own
        // foreground, which is what AppDialog now does.
        for (final money in <String, Color>{
          'success/income': AppColor.income,
          'error/outcome': AppColor.outcome,
        }.entries) {
          final ratio = AppColor.contrastRatio(
              money.value, AppColor.onColor(money.value));
          expect(ratio, greaterThanOrEqualTo(4.5),
              reason: '${money.key} text, $brightness, got ${ratio.toStringAsFixed(2)}');
        }
      });
    }

    test('the seed really reaches the roles, so the assertions above are not '
        'a default-palette accident', () {
      final light = AppTheme.of(Brightness.light).colorScheme;
      expect(AppTheme.seed, const Color(0xFF7C5CFF));
      expect(light.primary, isNot(const Color(0xFF6750A4)));
      expect(light.primary.computeLuminance(), lessThan(0.6));
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
