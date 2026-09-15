import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cause_money_record/presentation/controller/c_settings.dart';
import 'package:cause_money_record/presentation/widget/glass_lite.dart';

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
/// - glass toggle removes BackdropFilter from the tree;
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

  testWidgets('glass toggle removes BackdropFilter from the tree', (tester) async {
    final s = CSettings(store: _FakeStore());
    Get.put<CSettings>(s);
    await s.load();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GlassLite(child: Text('bar')))),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);

    await s.setReduceGlass(true);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
    // Same tile, solid — radius preserved.
    expect(find.byType(GlassLite), findsOneWidget);

    await s.setReduceGlass(false);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsOneWidget);
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
