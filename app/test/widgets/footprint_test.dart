import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  Future<PipelineController> pumpEditor(
    WidgetTester tester, {
    Pipeline? pipeline,
  }) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline ?? testPipeline());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  testWidgets('the summary bar reports the floor a build needs',
      (tester) async {
    final controller = await pumpEditor(tester);
    // Ten dupes need 1.13 Electrolyzers, so two are built: 2 × 2×2 tiles.
    expect(controller.solution.totalFootprintTiles, 8);
    expect(find.text('FLOOR'), findsOneWidget);
    expect(find.text('8 tiles'), findsOneWidget);
  });

  testWidgets('a node says its own size as well as its total', (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    expect(textContaining('8 tiles  (2×2)'), findsOneWidget);
  });

  testWidgets('a build of nothing but critters claims no floor',
      (tester) async {
    final pipeline = (PipelineBuilder(testDatabase, name: 'ranch')
          ..add('hatch', nodeId: 'hatches')
          ..pinCount('hatches', 6))
        .build();
    await pumpEditor(tester, pipeline: pipeline);

    expect(find.text('FLOOR'), findsNothing,
        reason: 'a Hatch takes up a stable, not a footprint of its own');
  });

  testWidgets('a selection totals its own floor', (tester) async {
    final pipeline = (PipelineBuilder(testDatabase, name: 'roomy')
          ..add('electrolyzer', nodeId: 'elec')
          ..add('oil_refinery', nodeId: 'refinery')
          ..pinCount('elec', 1)
          ..pinCount('refinery', 1))
        .build();
    final controller = await pumpEditor(tester, pipeline: pipeline);
    controller.selectNodes(['elec', 'refinery']);
    await tester.pump();

    // 2×2 plus 3×4.
    expect(find.text('16 tiles'), findsWidgets);
  });

  testWidgets('half a building still needs a whole one is worth of floor',
      (tester) async {
    final controller = await pumpEditor(tester);
    controller.pin(const BuildingCountPin(nodeId: 'elec', count: 2.1));
    await tester.pump();

    expect(controller.solution.nodes['elec']!.wholeCount, 3);
    expect(controller.solution.totalFootprintTiles, 12);
  });
}
