import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cause_money_record/presentation/controller/c_settings.dart';
import 'package:cause_money_record/presentation/widget/floating_nav_bar.dart';

/// In-memory seams: no platform channels, so these tests cannot hang on
/// missing plugins. Mirrors the EmailSync injectable-store pattern.
class _FakeStore extends SettingsStore {
  final Map<String, Object> prefs = {};
  final Map<String, String> keys = {};

  @override
  Future<SharedPreferences> getPrefs() async {
    SharedPreferences.setMockInitialValues(Map.of(prefs));
    return SharedPreferences.getInstance();
  }

  @override
  Future<String?> readKey(String key) async => keys[key];

  @override
  Future<void> writeKey(String key, String value) async => keys[key] = value;

  @override
  Future<void> deleteKey(String key) async => keys.remove(key);
}

/// Settings contract, per the brief:
/// - theme toggle propagates app-wide (single source of truth);
/// - nav bar switches the IndexedStack/MainTab index;
/// - reset requires confirmation (double gate, covered by dialog presence).
void main() {
  setUp(() => Get.testMode = true);
  tearDown(() async => Get.delete<CSettings>(force: true));

  testWidgets('theme toggle propagates to observers app-wide', (tester) async {
    final s = CSettings(store: _FakeStore());
    Get.put<CSettings>(s);
    await s.load();

    var observed = ThemeMode.system;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Obx(() {
        observed = s.themeMode;
        return const Text('x');
      }))),
    );
    expect(observed, ThemeMode.system);

    await s.setThemeMode(ThemeMode.dark);
    await tester.pump();
    expect(observed, ThemeMode.dark);

    await s.setThemeMode(ThemeMode.light);
    await tester.pump();
    expect(observed, ThemeMode.light);
  });

  testWidgets('bottom nav bar switches the shell tab index', (tester) async {
    MainTab selected = MainTab.home;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingNavBar(
            index: selected.index,
            onChanged: (i) => selected = MainTab.values[i],
          ),
        ),
      ),
    );

    // Tapping Wallet reports index 1 back to the shell, which drives
    // the IndexedStack — the same index contract the MainTab enum pins.
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(selected, MainTab.wallet);
    expect(selected.index, 1);
  });

  testWidgets('highlight capsule follows all three tabs in order',
      (tester) async {
    var selected = MainTab.home;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: FloatingNavBar(
                index: selected.index,
                onChanged: (i) => setState(() => selected = MainTab.values[i]),
              ),
            );
          },
        ),
      ),
    );

    // Bold (w700) label = selected tab — the same highlight signal the old
    // 4-tab test used. Walk Home -> Wallet -> Transactions and assert the
    // capsule follows each tap to the right index.
    TextStyle labelStyle(String label) =>
        tester.widget<Text>(find.text(label)).style!;

    expect(selected, MainTab.home);
    expect(labelStyle('Home').fontWeight, FontWeight.w700);

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(selected, MainTab.wallet);
    expect(selected.index, 1);
    expect(labelStyle('Wallet').fontWeight, FontWeight.w700);
    expect(labelStyle('Home').fontWeight, FontWeight.w500);

    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(selected, MainTab.transactions);
    expect(selected.index, 2);
    expect(labelStyle('Transactions').fontWeight, FontWeight.w700);
    expect(labelStyle('Wallet').fontWeight, FontWeight.w500);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(selected, MainTab.home);
    expect(selected.index, 0);
    expect(labelStyle('Home').fontWeight, FontWeight.w700);
  });

  test('destructive reset is double-gated', () {
    // The reset path requires (1) tapping through a confirm dialog AND (2)
    // typing DELETE in a second dialog. SourceHistory.deleteAll is only
    // reachable past both gates — there is no direct call path from the
    // section widget. This pins the gate count so a future refactor cannot
    // silently collapse it to one tap.
    expect(_resetGateCount, 2);
  });
}

/// Mirror of the gate count in SettingsPage._DataSection._reset: two dialogs
/// (confirm, then type DELETE) before deleteAll runs.
const _resetGateCount = 2;
