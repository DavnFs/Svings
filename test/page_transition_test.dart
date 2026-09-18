import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:cause_money_record/config/app_motion.dart';

/// Page transition contract.
///
/// Every page push in the app goes through GetX (Get.to / Get.off / Get.offAll)
/// and none of them overrides the transition, so the app-wide default in
/// GetMaterialApp is the single thing that decides how a page arrives. These
/// tests build that same configuration from the same tokens and assert the
/// incoming page is really in flight mid-navigation, forwards and back, so a
/// future change cannot quietly make navigation instant.
class _FirstPage extends StatelessWidget {
  const _FirstPage();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Get.to(() => const _SecondPage()),
            child: const Text('push'),
          ),
        ),
      );
}

class _SecondPage extends StatelessWidget {
  const _SecondPage();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Get.back(),
            child: const Text('pop'),
          ),
        ),
      );
}

const _screen = Size(412, 915);

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Same configuration the app builds in main.dart, from the same tokens.
    await tester.pumpWidget(const GetMaterialApp(
      defaultTransition: AppMotion.pageTransition,
      transitionDuration: AppMotion.pageTransitionDuration,
      home: _FirstPage(),
    ));
  }

  testWidgets('a push animates in instead of appearing at once', (tester) async {
    await pumpApp(tester);
    expect(find.byType(_SecondPage), findsNothing);

    await tester.tap(find.text('push'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // One frame in, the page is offset rather than already parked: the motion
    // is real, not a cut.
    final early = tester.getTopLeft(find.byType(_SecondPage)).dx;
    expect(early, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 84));
    final mid = tester.getTopLeft(find.byType(_SecondPage)).dx;
    expect(mid, greaterThan(0), reason: 'still travelling toward its place');
    expect(mid, lessThan(early), reason: 'and getting closer to it');

    // Settles promptly: nothing left to animate well inside a second.
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getTopLeft(find.byType(_SecondPage)).dx, 0);
  });

  testWidgets('a pop animates back out', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(_SecondPage)).dx, 0);

    await tester.tap(find.text('pop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    // Leaving the way it came in, so back and forward stay directional.
    expect(tester.getTopLeft(find.byType(_SecondPage)).dx, greaterThan(0));

    await tester.pumpAndSettle();
    expect(find.byType(_SecondPage), findsNothing);
    expect(find.byType(_FirstPage), findsOneWidget);
  });

  test('the duration stays in the snappy band', () {
    expect(AppMotion.pageTransitionDuration.inMilliseconds,
        inInclusiveRange(250, 300));
  });
}
