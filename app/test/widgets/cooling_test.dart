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

  testWidgets('a build that cools itself says so in the totals',
      (tester) async {
    // Heat arriving from outside the build — a steam room, a magma pool — and
    // a turbine put on top of it.
    final pipeline = (PipelineBuilder(testDatabase, name: 'Cooled')
          ..addSource('heat', x: 0, y: 0)
          ..add('steam_turbine', nodeId: 'turbine', x: 340, y: 0)
          ..connect('src_heat', sourcePortId, 'turbine', 'heat_in')
          ..pinCount('turbine', 1))
        .build();
    final controller = await pumpEditor(tester, pipeline);

    // One turbine deletes 877.59 kDTU/s and keeps 4 of it for itself.
    expect(controller.solution.totalHeatKdtu, closeTo(4 - 877.59, 1e-6));
    expect(find.text('HEAT'), findsOneWidget);
  });

  testWidgets('an Aquatuner is not a way of making heat disappear',
      (tester) async {
    final pipeline = (PipelineBuilder(testDatabase, name: 'Moved')
          ..add('electrolyzer', nodeId: 'elec', x: 0, y: 0)
          ..add('aquatuner_water', nodeId: 'tuner', x: 340, y: 0)
          ..connect('elec', 'heat_out', 'tuner', 'heat_in')
          ..pinCount('elec', 4))
        .build();
    final controller = await pumpEditor(tester, pipeline);

    // The Aquatuner takes the Electrolyzers' 5 kDTU/s out of the loop and puts
    // every last one of them somewhere else, so the base is no cooler.
    expect(controller.solution.totalHeatKdtu, closeTo(5, 1e-6));
  });

  testWidgets('a hot wire says what it costs to cool', (tester) async {
    // A geyser's 95 °C water into an Electrolyzer: the wire between them is
    // carrying a cooling bill, and the size of it decides whether the build
    // wants a steam room or nothing at all.
    final pipeline = (PipelineBuilder(testDatabase, name: 'Hot')
          ..add('water_geyser', nodeId: 'geyser', x: 0, y: 0)
          ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
          ..connectItem('geyser', 'elec', 'water')
          ..pinCount('elec', 1))
        .build();
    final controller = await pumpEditor(tester, pipeline);
    controller.select(EdgeSelection(controller.pipeline.edges.single.id));
    await tester.pumpAndSettle();

    expect(textContaining('kDTU/s more heat'), findsOneWidget);
    expect(textContaining('25 °C'), findsWidgets);
  });

  testWidgets('and a wire at room temperature says nothing at all',
      (tester) async {
    final pipeline = (PipelineBuilder(testDatabase, name: 'Cool')
          ..addSource('water', x: 0, y: 0)
          ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
          ..connectItem('src_water', 'elec', 'water')
          ..pinCount('elec', 1))
        .build();
    final controller = await pumpEditor(tester, pipeline);
    controller.setNodeTemperature('src_water', 25);
    controller.select(EdgeSelection(controller.pipeline.edges.single.id));
    await tester.pumpAndSettle();

    // Nought kDTU/s is not a fact worth a line on every wire in a cool build.
    expect(textContaining('kDTU/s more heat'), findsNothing);
    expect(textContaining('colder than'), findsNothing);
  });
}
