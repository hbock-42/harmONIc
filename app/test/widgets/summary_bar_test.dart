import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  /// A build with something in every total — power, heat, floor, dupe time,
  /// build materials — so the bar is as crowded as it gets.
  Pipeline crowded() => (PipelineBuilder(testDatabase, name: 'Crowded')
        ..addSource('sedimentary_rock', x: 0, y: 0)
        ..add('hatch', nodeId: 'hatches', x: 340, y: 0)
        ..add('grooming_station', nodeId: 'station', x: 340, y: 300)
        ..add('coal_generator', nodeId: 'gen', x: 680, y: 0)
        ..addSink('power', x: 1020, y: 0)
        ..addSink('egg', x: 1020, y: 200)
        ..addSink('meat', x: 1020, y: 400)
        ..connectItem('src_sedimentary_rock', 'hatches', 'sedimentary_rock')
        ..connectItem('station', 'hatches', 'grooming')
        ..connectItem('hatches', 'gen', 'coal')
        ..connectItem('hatches', 'sink_egg', 'egg')
        ..connectItem('hatches', 'sink_meat', 'meat')
        ..connectItem('gen', 'sink_power', 'power')
        ..pinCount('gen', 1))
      .build();

  for (final width in [1440.0, 1100.0, 900.0, 720.0, 600.0]) {
    testWidgets('the summary bar fits at ${width.toStringAsFixed(0)} px',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = testController(pipeline: crowded());
      await tester.pumpWidget(harness(EditorScreen(
        controller: controller,
        library: testLibrary(),
        workspace: await testWorkspace(controller),
        displaySettings: testDisplay(),
      )));

      // A vertical overflow here is content nobody can see, which for a row of
      // totals means a number that is simply missing.
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [1440.0, 1000.0, 760.0]) {
    testWidgets('the panels fit at ${width.toStringAsFixed(0)} px too',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = testController(pipeline: crowded());
      await tester.pumpWidget(harness(EditorScreen(
        controller: controller,
        library: testLibrary(),
        workspace: await testWorkspace(controller),
        displaySettings: testDisplay(),
      )));

      // The inspector, with a node that has everything to say about itself.
      controller.select(const NodeSelection('hatches'));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // And the pipelines menu over the top of it.
      await tester.tap(find.text('Pipelines'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}