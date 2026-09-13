import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cause_money_record/config/app_color.dart';

/// The palette adapts to brightness at runtime, which is only correct if
/// `MaterialApp.builder` sets it before the page tree builds.
void main() {
  tearDown(() => AppColor.useBrightness(Brightness.light));

  test('defaults to the light palette', () {
    expect(AppColor.surface, const Color(0xFFF8F9FA));
    expect(AppColor.card, Colors.white);
    expect(AppColor.textPrimary, const Color(0xFF1A1A1A));
  });

  test('switches surfaces and text for dark', () {
    AppColor.useBrightness(Brightness.dark);
    expect(AppColor.surface, const Color(0xFF141218));
    expect(AppColor.card, const Color(0xFF211F26));
    expect(AppColor.textPrimary, const Color(0xFFE6E0E9));
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
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
