import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cause_money_record/config/display_refresh.dart';
import 'package:cause_money_record/presentation/widget/floating_nav_bar.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// Nav bar geometry contract, from the spec this replaced the equal-cell bar
/// with:
///
/// - the pill hugs its content, it does not stretch to the screen;
/// - only the selected tab carries an icon, and an unselected tab reserves no
///   space for one;
/// - the capsule is sized per tab, never the pill width over the tab count;
/// - the add button shares the pill's row, its height and its vertical center.
///
/// Widths here are relational rather than hardcoded, so the numbers hold with
/// any font metrics.
const _screen = Size(412, 915);

Future<void> _loadRoboto() async {
  // Real metrics, not the test font's square glyphs: a label width has to mean
  // something for the capsule sizing to be checked. Found by walking up from
  // the running binary, so no machine-specific path is baked in.
  final dir = _materialFonts();
  if (dir == null) {
    fail('Could not find bin/cache/artifacts/material_fonts in the Flutter SDK. '
        'This suite checks label widths against real font metrics.');
  }
  final loader = FontLoader('Roboto');
  for (final name in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']) {
    final file = File('${dir.path}/$name');
    if (!file.existsSync()) {
      fail('Missing ${file.path} in the Flutter SDK font cache.');
    }
    loader.addFont(
      Future<ByteData>.value(ByteData.view(file.readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

Directory? _materialFonts() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (true) {
    for (final path in [
      '${dir.path}/cache/artifacts/material_fonts',
      '${dir.path}/bin/cache/artifacts/material_fonts',
    ]) {
      final candidate = Directory(path);
      if (candidate.existsSync()) return candidate;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

/// Pumps the bar alone at phone width, hosted statefully so a tap really moves
/// the selection the way MainShell does.
Future<void> _pumpNav(
  WidgetTester tester, {
  required int index,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  var selected = index;

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C5CFF)),
      ),
      // Scaffold, not a bare Stack: it is what supplies the app's default text
      // style, so the labels measure against the font the app really uses.
      home: Scaffold(
        extendBody: true,
        body: Stack(children: [
          const SizedBox.expand(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            // Always wrapped, so a test that flips a flag swaps the data instead
            // of rebuilding the bar from scratch and skipping didUpdateWidget.
            child: MediaQuery(
              data: MediaQueryData(disableAnimations: disableAnimations),
              child: StatefulBuilder(
                builder: (context, setState) => FloatingNavBar(
                  index: selected,
                  onChanged: (i) => setState(() => selected = i),
                  onAddPressed: _noop,
                ),
              ),
            ),
          ),
        ]),
      ),
    ),
  );
}

Rect _tabRect(WidgetTester tester, MainTab tab) =>
    tester.getRect(find.byKey(Key('nav_tab_${tab.name}')));

Rect _contentRect(WidgetTester tester, MainTab tab) =>
    tester.getRect(find.byKey(Key('nav_content_${tab.name}')));

void main() {
  setUpAll(_loadRoboto);

  group('pill hugs its content', () {
    testWidgets('pill adds only its padding to the tabs', (tester) async {
      await _pumpNav(tester, index: 0);

      final pill = tester.getRect(find.byKey(const Key('nav_pill')));
      final tabs = [for (final tab in MainTab.values) _tabRect(tester, tab)];
      final tabsWidth = tabs.fold<double>(0, (sum, r) => sum + r.width);
      // The pill's height over its tab height is its padding, so this asserts
      // the pill contributes padding and nothing else. A bar that divided the
      // available width by the tab count would sit at the screen width instead.
      final padding = (pill.height - tabs[0].height) / 2;
      expect(pill.width, closeTo(tabsWidth + padding * 2, 0.5));
    });

    testWidgets('pill is narrower than the screen, and the row fits',
        (tester) async {
      await _pumpNav(tester, index: 0);

      final pill = tester.getRect(find.byKey(const Key('nav_pill')));
      final fab = tester.getRect(find.byKey(const Key('main_new_entry_fab')));
      expect(pill.width, lessThan(_screen.width * 0.8));
      expect(fab.right, lessThanOrEqualTo(_screen.width));
      // Centered as a group: equal air on both sides.
      expect(pill.left, closeTo(_screen.width - fab.right, 1));
    });
  });

  group('icons', () {
    for (final tab in MainTab.values) {
      testWidgets('only the selected tab shows an icon (${tab.name})',
          (tester) async {
        await _pumpNav(tester, index: tab.index);

        final inPill = find.descendant(
          of: find.byKey(const Key('nav_pill')),
          matching: find.byType(Icon),
        );
        expect(inPill, findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(Key('nav_tab_${tab.name}')),
            matching: find.byType(Icon),
          ),
          findsOneWidget,
        );
        // To the left of its label, not above it.
        final icon = tester.getRect(inPill);
        expect(icon.right, lessThan(_contentRect(tester, tab).right));
      });
    }

    testWidgets('a tab is narrower when it is not selected', (tester) async {
      await _pumpNav(tester, index: 0);
      await tester.pumpAndSettle();
      final homeSelected = _tabRect(tester, MainTab.home).width;

      await _pumpNav(tester, index: 2);
      await tester.pumpAndSettle();
      final homeUnselected = _tabRect(tester, MainTab.home).width;
      final transactionsSelected = _tabRect(tester, MainTab.transactions).width;

      // Selection is what opens the icon slot: if the space were reserved
      // either way, these would be equal.
      expect(homeSelected, greaterThan(homeUnselected));
      expect(transactionsSelected, greaterThan(homeSelected));
    });
  });

  group('capsule', () {
    for (final tab in MainTab.values) {
      testWidgets('capsule matches the selected tab exactly (${tab.name})',
          (tester) async {
        await _pumpNav(tester, index: tab.index);

        final capsule = tester.getRect(find.byKey(const Key('nav_capsule')));
        expect(capsule, _tabRect(tester, tab));
      });
    }

    testWidgets('capsule is not the pill width over the tab count',
        (tester) async {
      await _pumpNav(tester, index: 0);
      final capsule = tester.getRect(find.byKey(const Key('nav_capsule')));
      final pill = tester.getRect(find.byKey(const Key('nav_pill')));
      final widths = [
        for (final tab in MainTab.values) _tabRect(tester, tab).width
      ];

      // The exact failure this replaced: one width for every tab.
      expect(capsule.width, isNot(closeTo(pill.width / MainTab.values.length, 0.5)));
      expect(widths.toSet().length, MainTab.values.length);
    });

    testWidgets('capsule moves and resizes while switching', (tester) async {
      await _pumpNav(tester, index: 0);
      await tester.pumpAndSettle();
      final from = _tabRect(tester, MainTab.home);

      await tester.tap(find.text('Transactions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final early = tester.getRect(find.byKey(const Key('nav_capsule')));
      await tester.pump(const Duration(milliseconds: 60));
      final late = tester.getRect(find.byKey(const Key('nav_capsule')));

      await tester.pumpAndSettle();
      final settled = tester.getRect(find.byKey(const Key('nav_capsule')));
      final to = _tabRect(tester, MainTab.transactions);

      // Landed on the destination tab, whose rect is a different size than the
      // one it left: that difference is the per-tab sizing working.
      expect(settled, to);
      expect(to.width, isNot(closeTo(from.width, 1)));

      // In flight it is past where it started, short of the target, and a
      // different width at each sample, so X and width are both animating.
      expect(early.left, greaterThan(from.left));
      expect(late.left, greaterThan(early.left));
      expect(late.left, lessThan(to.left));
      expect(early.width, isNot(closeTo(from.width, 1)));
      expect(late.width, isNot(closeTo(early.width, 1)));
    });

    testWidgets('reduced motion jumps straight to the target', (tester) async {
      await _pumpNav(tester, index: 0, disableAnimations: true);
      await _pumpNav(tester, index: 2, disableAnimations: true);
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const Key('nav_capsule'))),
        _tabRect(tester, MainTab.transactions),
      );
    });
  });

  group('add button', () {
    testWidgets('shares the pill row: same height, same center, fixed gap',
        (tester) async {
      await _pumpNav(tester, index: 0);

      final pill = tester.getRect(find.byKey(const Key('nav_pill')));
      final fab = tester.getRect(find.byKey(const Key('main_new_entry_fab')));

      expect(fab.height, closeTo(pill.height, 0.5));
      expect(fab.center.dy, closeTo(pill.center.dy, 0.5));
      expect(fab.left, greaterThan(pill.right));
      expect(fab.left - pill.right, closeTo(12, 0.5));
      // A circle, like the reference's search button.
      expect(fab.width, closeTo(fab.height, 0.5));
    });
  });

  group('refresh rate request', () {
    DisplayMode mode(int id, int w, int h, double hz) =>
        DisplayMode(id: id, width: w, height: h, refreshRate: hz);

    test('picks the fastest mode at the active resolution', () {
      final active = mode(1, 1080, 2340, 60);
      final best = DisplayRefresh.highest([
        DisplayMode.auto,
        active,
        mode(2, 1440, 3120, 120),
        mode(3, 1080, 2340, 90),
      ], active);
      expect(best.refreshRate, 90);
      expect(best.width, 1080);
    });

    test('never picks a lower resolution to buy hertz', () {
      final active = mode(1, 1440, 3120, 60);
      final best = DisplayRefresh.highest([
        mode(2, 1080, 2340, 120),
        active,
      ], active);
      expect(best, active);
    });

    test('no faster mode leaves the active one alone', () {
      final active = mode(1, 1080, 2340, 120);
      expect(
        DisplayRefresh.highest([active, mode(2, 1080, 2340, 60)], active),
        active,
      );
    });
  });
}

void _noop() {}
