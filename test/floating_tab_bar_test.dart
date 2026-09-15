import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cause_money_record/presentation/widget/floating_tab_bar.dart';

/// The pill indicator, the tab cells, and the IndexedStack pages all derive
/// from [MainTab.values] order — regression guard for the bug where Expense
/// highlighted between Home and Income and History highlighted Income.
void main() {
  testWidgets('each tab highlights its own indicator position', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: _Harness()),
    );

    // Home selected initially: first tab highlighted.
    expect(_selectedLabel(tester), 'Home');

    // Walk every tab via real taps and confirm the highlight follows.
    for (final tab in MainTab.values) {
      await tester.tap(find.text(tab.label));
      await tester.pumpAndSettle();
      expect(_selectedLabel(tester), tab.label,
          reason: 'tapping ${tab.label} should highlight ${tab.label}');
    }
  });

  test('MainTab order matches the shell page order', () {
    // MainShell builds IndexedStack children in this order; if anyone reorders
    // one side without the other, the indicator lands on the wrong tab.
    expect(MainTab.values.map((t) => t.label),
        ['Home', 'Income', 'Expense', 'History']);
  });
}

/// Minimal host: pill + a readout of which tab it thinks is selected.
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  MainTab _tab = MainTab.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Expanded(child: Center(child: Text('page:${_tab.label}', key: Key('page_${_tab.label}')))),
        FloatingTabBar(index: _tab.index, onChanged: (i) => setState(() => _tab = MainTab.values[i])),
      ]),
    );
  }
}

String _selectedLabel(WidgetTester tester) {
  // The highlighted tab renders its label in accent; find which one.
  for (final tab in MainTab.values) {
    final finder = find.text(tab.label);
    expect(finder, findsOneWidget);
    final text = tester.widget<Text>(finder);
    if (text.style?.fontWeight == FontWeight.w700) return tab.label;
  }
  fail('no tab highlighted');
}
