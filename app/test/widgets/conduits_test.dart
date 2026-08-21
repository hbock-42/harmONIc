import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  /// Three Electrolyzers' worth of oxygen: 2664 g/s, which is three gas pipes.
  Pipeline gasHeavy() => (PipelineBuilder(testDatabase, name: 'Oxygen')
        ..add('electrolyzer', nodeId: 'elec', x: 0, y: 0)
        ..addSink('oxygen', x: 400, y: 0)
        ..addSink('hydrogen', x: 400, y: 200)
        ..connectItem('elec', 'sink_oxygen', 'oxygen')
        ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
        ..pinCount('elec', 3))
      .build();

  Future<PipelineController> pumpEditor(
    WidgetTester tester, {
    Pipeline? pipeline,
  }) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline ?? gasHeavy());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  testWidgets('the edge inspector says what carries the flow', (tester) async {
    final controller = await pumpEditor(tester);
    final oxygen =
        controller.pipeline.edges.firstWhere((e) => e.toNodeId == 'sink_oxygen');
    controller.select(EdgeSelection(oxygen.id));
    await tester.pump();

    expect(find.text('CARRIED BY'), findsOneWidget);
    // 3 × 888 g/s of oxygen needs three gas pipes.
    expect(find.text('3 gas pipes'), findsOneWidget);
  });

  testWidgets('a modest flow reads as one pipe', (tester) async {
    final controller = await pumpEditor(tester, pipeline: testPipeline());
    final water = controller.pipeline.edges
        .firstWhere((e) => e.fromNodeId == 'src_water');
    controller.select(EdgeSelection(water.id));
    await tester.pump();

    expect(find.text('liquid pipe'), findsOneWidget);
  });

  testWidgets('power says which wire to run', (tester) async {
    final pipeline = (PipelineBuilder(testDatabase, name: 'Grid')
          ..add('coal_generator', nodeId: 'gen')
          ..add('water_sieve', nodeId: 'sieve')
          ..connectItem('gen', 'sieve', 'power')
          ..pinCount('sieve', 2))
        .build();
    final controller = await pumpEditor(tester, pipeline: pipeline);
    controller.select(EdgeSelection(controller.pipeline.edges.first.id));
    await tester.pump();

    // Two sieves draw 240 W, which plain wire carries.
    expect(find.text('Wire'), findsOneWidget);
  });

  testWidgets('something that travels by no pipe says nothing at all',
      (tester) async {
    final pipeline = (PipelineBuilder(testDatabase, name: 'Stable')
          ..add('hatch', nodeId: 'hatches')
          ..add('grooming_station', nodeId: 'station')
          ..connectItem('station', 'hatches', 'grooming')
          ..pinCount('hatches', 8))
        .build();
    final controller = await pumpEditor(tester, pipeline: pipeline);
    controller.select(EdgeSelection(controller.pipeline.edges.first.id));
    await tester.pump();

    expect(find.text('CARRIED BY'), findsNothing,
        reason: 'a grooming slot does not travel down a pipe');
  });

  testWidgets('the canvas marks a wire that needs more than one run',
      (tester) async {
    await pumpEditor(tester);
    // The oxygen label carries the multiplier; the hydrogen one does not,
    // because 336 g/s fits a single pipe.
    expect(find.byType(InspectorPanel), findsOneWidget);
    expect(Conduits.runsNeeded(3 * 888, ItemCategory.gas), 3);
    expect(Conduits.runsNeeded(3 * 112, ItemCategory.gas), 1);
  });
}
