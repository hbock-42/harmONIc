import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  Future<PipelineController> pumpEditor(
    WidgetTester tester,
    Pipeline pipeline,
  ) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  Pipeline spom() => (PipelineBuilder(testDatabase, name: 'SPOM')
        ..addSource('water', x: 0, y: 0)
        ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
        ..addSink('oxygen', x: 680, y: 0)
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'sink_oxygen', 'oxygen')
        ..pinCount('elec', 3))
      .build();

  testWidgets('a node says what the next one would buy', (tester) async {
    final controller = await pumpEditor(tester, spom());
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    expect(find.text('GOING FROM 3 TO 4'), findsOneWidget);
    // A kilogram of water in, 888 g/s of oxygen out, 120 W to run it.
    expect(textContaining('+888.0 g/s Oxygen'), findsOneWidget);
    expect(textContaining('−1.0 kg/s Water'), findsOneWidget);
    expect(textContaining('−120 W'), findsOneWidget);
  });

  testWidgets('and it follows the units the rest of the app is in',
      (tester) async {
    final controller = await pumpEditor(tester, spom());
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    await tester.tap(find.text('g/s'));
    await tester.pumpAndSettle();

    expect(textContaining('/cycle'), findsWidgets);
  });

  testWidgets('a supply node is not something you have one more of',
      (tester) async {
    final controller = await pumpEditor(tester, spom());
    controller.select(const NodeSelection('src_water'));
    await tester.pump();

    expect(textContaining('GOING FROM'), findsNothing);
  });

  testWidgets('nor is a build nobody has given an amount', (tester) async {
    final loose = (PipelineBuilder(testDatabase, name: 'Loose')
          ..addSource('water', x: 0, y: 0)
          ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
          ..connectItem('src_water', 'elec', 'water'))
        .build();
    final controller = await pumpEditor(tester, loose);
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    expect(textContaining('GOING FROM'), findsNothing);
  });
}
