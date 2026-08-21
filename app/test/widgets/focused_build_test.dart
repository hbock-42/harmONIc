import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  /// A SPOM that pays for itself and a Metal Refinery that does not, sharing a
  /// page and sharing nothing else.
  Pipeline twoBuilds() => (PipelineBuilder(testDatabase, name: 'Two builds')
        ..addSource('water', x: 0, y: 0)
        ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
        ..add('hydrogen_generator', nodeId: 'hgen', x: 680, y: 0)
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'hgen', 'hydrogen')
        ..pinCount('elec', 4)
        ..addSource('iron_ore', x: 0, y: 500)
        ..add('metal_refinery', nodeId: 'refinery', x: 340, y: 500)
        ..connectItem('src_iron_ore', 'refinery', 'iron_ore')
        ..pinCount('refinery', 1))
      .build();

  Future<PipelineController> pumpEditor(
    WidgetTester tester, {
    Pipeline? pipeline,
  }) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline ?? twoBuilds());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  testWidgets('with nothing selected the totals say they are the whole canvas',
      (tester) async {
    await pumpEditor(tester);

    expect(find.text('WHOLE CANVAS'), findsOneWidget);
  });

  testWidgets('and those totals are the sum of two builds, true of neither',
      (tester) async {
    final controller = await pumpEditor(tester);

    // 3 584 W of generation against 480 W of Electrolyzers and 1 200 W of
    // refinery. The page nets out positive while one of the two builds on it
    // is 1.2 kW in the red.
    expect(controller.solution.netPowerWatts, closeTo(3584 - 480 - 1200, 1e-6));
    expect(controller.focusedSolution.netPowerWatts,
        controller.solution.netPowerWatts);
  });

  testWidgets('selecting a node scopes the totals to its build',
      (tester) async {
    final controller = await pumpEditor(tester);

    controller.select(const NodeSelection('refinery'));
    await tester.pump();

    expect(find.text('THIS BUILD'), findsOneWidget);
    expect(controller.focusedSolution.netPowerWatts, closeTo(-1200, 1e-6));

    controller.select(const NodeSelection('elec'));
    await tester.pump();
    expect(controller.focusedSolution.netPowerWatts, closeTo(3584 - 480, 1e-6));
  });

  testWidgets('one build on the page needs no such qualification',
      (tester) async {
    final controller = await pumpEditor(tester, pipeline: testPipeline());

    expect(controller.builds, hasLength(1));
    expect(controller.focusedBuild, isNull);
    expect(find.text('THIS BUILD'), findsOneWidget);
    expect(find.text('WHOLE CANVAS'), findsNothing);
  });
}
