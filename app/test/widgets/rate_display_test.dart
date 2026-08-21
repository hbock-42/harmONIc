import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/panels/summary_bar.dart';
import 'package:oni_pipeline/state/display_controller.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

void main() {
  late PipelineController controller;
  late DisplayController display;
  late MemoryJsonStore store;

  Future<void> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    store = MemoryJsonStore();
    display = testDisplay(store);
    controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: display,
    )));
  }

  testWidgets('the app starts in grams per second', (tester) async {
    await pumpEditor(tester);
    expect(display.display, RateDisplay.perSecond);
    expect(textContaining('kg/s'), findsWidgets);
    expect(textContaining('kg/cycle'), findsNothing);
  });

  testWidgets('the top-bar button switches every rate at once',
      (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('g/s'));
    await tester.pump();

    expect(display.display, RateDisplay.perCycle);
    expect(textContaining('kg/cycle'), findsWidgets);
    expect(textContaining('kg/s'), findsNothing,
        reason: 'a mixture of units would be worse than either');
  });

  testWidgets('clicking a rate in the summary bar toggles it too',
      (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.descendant(
      of: find.byType(SummaryBar),
      matching: find.byType(OniRate),
    ).first);
    await tester.pump();

    expect(display.display, RateDisplay.perCycle);
  });

  testWidgets('clicking a rate in the inspector toggles it', (tester) async {
    await pumpEditor(tester);
    controller.select(const NodeSelection('src_water'));
    await tester.pump();

    expect(find.text('RATE'), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(InspectorPanel),
      matching: find.byType(OniRate),
    ).first);
    await tester.pump();

    expect(display.display, RateDisplay.perCycle);
    expect(textContaining('kg/cycle'), findsWidgets);
  });

  testWidgets('a per-cycle figure is the per-second one times a cycle',
      (tester) async {
    await pumpEditor(tester);
    controller.select(const NodeSelection('src_water'));
    await tester.pump();

    // Ten dupes drink 1126.13 g/s of water, shown as 1.13 kg/s.
    final perSecond = controller.solution.nodes['src_water']!.count;
    expect(perSecond, closeTo(1126.13, 0.01));
    expect(textContaining('1.13 kg/s'), findsWidgets);

    await display.toggle();
    await tester.pump();
    // The same flow over a cycle: 675.68 kg.
    expect(textContaining('675.68 kg/cycle'), findsWidgets);
  });

  testWidgets('a capacity is not multiplied by the cycle', (tester) async {
    // Eight grooming slots is eight either way; scaling it would read as 4800.
    await pumpEditor(tester);
    final grooming = testDatabase.itemOrThrow('grooming');
    expect(grooming.formatRate(8, RateDisplay.perCycle), '8.00');
    expect(grooming.isCapacity, isTrue);
  });

  testWidgets('the choice is remembered', (tester) async {
    await pumpEditor(tester);
    await display.toggle();
    expect(store.data!['rateDisplay'], 'perCycle');

    final reopened = DisplayController(store);
    await reopened.load();
    expect(reopened.display, RateDisplay.perCycle);
  });

  testWidgets('the button names where a click takes you', (tester) async {
    await pumpEditor(tester);
    expect(display.currentLabel, 'g/s');
    expect(display.otherLabel, 'kg/cycle');

    await display.toggle();
    await tester.pump();
    expect(find.text('kg/cycle'), findsWidgets);
  });
}
