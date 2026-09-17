import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cause_money_record/presentation/controller/c_settings.dart';
import 'package:cause_money_record/presentation/widget/app_lock.dart';

class _FakeStore extends SettingsStore {
  final Map<String, Object> prefs;
  _FakeStore(this.prefs);

  @override
  Future<SharedPreferences> getPrefs() async {
    SharedPreferences.setMockInitialValues(Map.of(prefs));
    return SharedPreferences.getInstance();
  }

  @override
  Future<String?> readKey(String key) async => null;
}

/// App-lock contract: the toggle must actually gate content.
/// - lock off  -> child visible, no cover.
/// - lock on   -> opaque cover over the child from the first frame
///   (cold-start path), dismissible only via the Unlock action.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(() async => Get.delete<CSettings>(force: true));

  testWidgets('lock OFF shows content with no cover', (tester) async {
    final s = CSettings(store: _FakeStore({}));
    Get.put<CSettings>(s);
    await s.load();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLock(child: Text('secret')))),
    );
    await tester.pump();

    expect(find.text('secret'), findsOneWidget);
    expect(find.text('svings is locked'), findsNothing);
  });

  testWidgets('lock ON covers content from the first frame', (tester) async {
    final s = CSettings(store: _FakeStore({'settings.app_lock': true}));
    Get.put<CSettings>(s);
    await s.load();
    expect(s.appLock, isTrue);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLock(child: Text('secret')))),
    );
    await tester.pump();

    // Cover present…
    expect(find.text('svings is locked'), findsOneWidget);
    expect(find.byKey(const Key('applock_unlock')), findsOneWidget);
    // …and the child subtree is still mounted underneath (needed for instant
    // unlock) — the opaque cover is what hides it, not removal.
    expect(find.text('secret'), findsOneWidget);
  });

  testWidgets('back button cannot dismiss the lock cover', (tester) async {
    final s = CSettings(store: _FakeStore({'settings.app_lock': true}));
    Get.put<CSettings>(s);
    await s.load();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLock(child: Text('secret')))),
    );
    await tester.pump();

    expect(find.text('svings is locked'), findsOneWidget);
    // System back while locked: the cover's PopScope(canPop: false) holds,
    // so the route — and the lock — survive.
    final dynamic widgetsBinding = tester.binding;
    await widgetsBinding.handlePopRoute();
    await tester.pump();
    expect(find.text('svings is locked'), findsOneWidget);
    expect(find.byKey(const Key('applock_unlock')), findsOneWidget);
  });
}
