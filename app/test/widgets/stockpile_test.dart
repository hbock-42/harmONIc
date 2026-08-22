import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  /// Coal into a generator, with the coal coming out of a store rather than a
  /// ranch — which is the case the third kind of pin exists for.
  Pipeline burning() => (PipelineBuilder(testDatabase, name: 'Store')
        ..addSource('coal', x: 0, y: 0)
        ..add('coal_generator', nodeId: 'gen', x: 340, y: 0)
        ..addSink('power', x: 680, y: 0)
        ..connectItem('src_coal', 'gen', 'coal')
        ..connectItem('gen', 'sink_power', 'power'))
      .build();

  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: burning());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    controller.select(const NodeSelection('src_coal'));
    await tester.pump();
    return controller;
  }

  testWidgets('a supply can be told what is in store and for how long',
      (tester) async {
    final controller = await pumpEditor(tester);

    await tester.tap(find.text('or say what you have in store'));
    await tester.pump();

    await tester.enterText(find.byKey(stockAmountFieldKey), '2000');
    await tester.pump();
    await tester.enterText(find.byKey(stockCyclesFieldKey), '20');
    await tester.pump();

    // Two tonnes over twenty cycles is 166.7 g/s, and the build is sized to it.
    final pin = controller.pinFor('src_coal');
    expect(pin, isA<StockPin>());
    expect((pin! as StockPin).ratePerSecond, closeTo(2000000 / 12000, 1e-6));
    expect(controller.solution.status, SolveStatus.solved);
    expect(controller.solution.nodes['src_coal']!.count,
        closeTo(166.667, 1e-3));
    // A generator burns 1 kg/s, so that store keeps a sixth of one running.
    expect(controller.solution.nodes['gen']!.count, closeTo(0.1667, 1e-3));
  });

  testWidgets('and it says what rate that works out at', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('or say what you have in store'));
    await tester.pump();
    await tester.enterText(find.byKey(stockAmountFieldKey), '2000');
    await tester.pump();
    await tester.enterText(find.byKey(stockCyclesFieldKey), '20');
    await tester.pump();

    // The rate turns up in the summary bar and on the wire as well, which is
    // the point of it; here we want the sentence under the fields.
    expect(textContaining('and that is what the build is sized to'),
        findsOneWidget);
    expect(textContaining('the store runs out sooner'), findsOneWidget);
  });

  testWidgets('nought cycles is refused rather than dividing by it',
      (tester) async {
    final controller = await pumpEditor(tester);
    await tester.tap(find.text('or say what you have in store'));
    await tester.pump();
    await tester.enterText(find.byKey(stockAmountFieldKey), '2000');
    await tester.pump();
    await tester.enterText(find.byKey(stockCyclesFieldKey), '0');
    await tester.pump();

    expect(controller.pinFor('src_coal'), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a building is not asked what it has in store', (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('gen'));
    await tester.pump();

    // A stockpile is a fact about a supply. "I have 2 t of coal generator" is
    // not a thing anybody says.
    expect(find.text('or say what you have in store'), findsNothing);
  });
}
