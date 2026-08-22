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

  testWidgets('a building can be told it only runs part of the time',
      (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    expect(find.text('RUNS'), findsOneWidget);
    expect(find.text('All the time'), findsOneWidget);

    await tester.ensureVisible(find.text('50%'));
    await tester.pump();
    await tester.tap(find.text('50%'));
    await tester.pump();

    expect(controller.pipeline.nodeOrThrow('elec').uptime, 0.5);
  });

  testWidgets('and then you need twice as many of them', (tester) async {
    final controller = await pumpEditor(tester);
    final before = controller.solution.nodes['elec']!;

    controller.setNodeUptime('elec', 0.5);
    await tester.pump();
    final after = controller.solution.nodes['elec']!;

    // The work is the same — a crew of ten still breathes what it breathes —
    // but half-time Electrolyzers means twice the Electrolyzers.
    expect(after.count, closeTo(before.count, 1e-9));
    expect(after.physicalCount, closeTo(before.physicalCount * 2, 1e-9));
    expect(after.wholeCount, greaterThan(before.wholeCount));
  });

  testWidgets('the inspector says what that costs in buildings',
      (tester) async {
    final controller = await pumpEditor(tester);
    controller.setNodeUptime('elec', 0.5);
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    expect(textContaining('Running 50 % of the time'), findsOneWidget);
    expect(textContaining('there is simply more of it standing there'),
        findsOneWidget);
  });

  testWidgets('a geyser is not offered it, having its own control',
      (tester) async {
    final controller = await pumpEditor(
      tester,
      pipeline: (PipelineBuilder(testDatabase, name: 'Geyser')
            ..add('water_geyser', nodeId: 'geyser', x: 0, y: 0)
            ..pinCount('geyser', 1))
          .build(),
    );
    controller.select(const NodeSelection('geyser'));
    await tester.pump();

    // A geyser's duty cycle is a fact about the world, not a switch.
    expect(find.text('RUNS'), findsNothing);
    expect(find.text('ASSUME ACTIVE'), findsOneWidget);
  });

  testWidgets('nor is a critter, which has no off switch', (tester) async {
    final controller = await pumpEditor(
      tester,
      pipeline: (PipelineBuilder(testDatabase, name: 'Ranch')
            ..add('hatch', nodeId: 'hatches', x: 0, y: 0)
            ..pinCount('hatches', 4))
          .build(),
    );
    controller.select(const NodeSelection('hatches'));
    await tester.pump();

    expect(find.text('RUNS'), findsNothing);
  });
}
