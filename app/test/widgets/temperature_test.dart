import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  /// A geyser at 95 °C feeding an Electrolyzer whose oxygen leaves at 70 °C.
  Pipeline hotAndCool() => (PipelineBuilder(testDatabase, name: 'Hot water')
        ..add('water_geyser', nodeId: 'geyser', x: 0, y: 0)
        ..add('electrolyzer', nodeId: 'elec', x: 360, y: 0)
        ..addSink('oxygen', x: 720, y: 0)
        ..addSink('hydrogen', x: 720, y: 200)
        ..connectItem('geyser', 'elec', 'water')
        ..connectItem('elec', 'sink_oxygen', 'oxygen')
        ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
        ..pinCount('geyser', 1))
      .build();

  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: hotAndCool());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  testWidgets('a port shows the temperature the game fixes for it',
      (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    // The Electrolyzer's gases leave at 70 °C.
    expect(find.text('70 °C'), findsNWidgets(2));
  });

  testWidgets('a port with no stated temperature shows none', (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    // Water in has no fixed temperature, so nothing is claimed about it.
    expect(find.byType(InspectorPanel), findsOneWidget);
    expect(find.textContaining('°C'), findsNWidgets(2));
  });

  testWidgets('an edge says what temperature the flow arrives at',
      (tester) async {
    final controller = await pumpEditor(tester);
    final water = controller.pipeline.edges
        .firstWhere((e) => e.fromNodeId == 'geyser');
    controller.select(EdgeSelection(water.id));
    await tester.pump();

    expect(find.text('ARRIVES AT'), findsOneWidget);
    expect(find.text('95 °C'), findsOneWidget);
  });

  testWidgets('a flow past the common overheat point is called out',
      (tester) async {
    final controller = await pumpEditor(tester);
    final water = controller.pipeline.edges
        .firstWhere((e) => e.fromNodeId == 'geyser');
    controller.select(EdgeSelection(water.id));
    await tester.pump();

    expect(textContaining('75 °C most buildings overheat at'), findsOneWidget);
  });

  testWidgets('a cool flow is not called out', (tester) async {
    final controller = await pumpEditor(tester);
    final oxygen = controller.pipeline.edges
        .firstWhere((e) => e.toNodeId == 'sink_oxygen');
    controller.select(EdgeSelection(oxygen.id));
    await tester.pump();

    expect(find.text('70 °C'), findsOneWidget);
    expect(textContaining('overheat'), findsNothing);
  });

  testWidgets('the warning is about attention, not a prediction',
      (tester) async {
    final controller = await pumpEditor(tester);
    final water = controller.pipeline.edges
        .firstWhere((e) => e.fromNodeId == 'geyser');
    controller.select(EdgeSelection(water.id));
    await tester.pump();

    // It must not claim something will overheat: the model cannot know.
    expect(textContaining('cannot see'), findsOneWidget);
  });
}
