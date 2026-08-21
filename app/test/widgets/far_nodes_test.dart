import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/geometry.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  final canvasKey = GlobalKey<GraphCanvasState>();

  /// Nodes at the far corners of a build: one at negative world coordinates,
  /// one well past the width of any window. Both were visible and unclickable.
  Pipeline spreadOut() => (PipelineBuilder(testDatabase, name: 'Spread')
        ..addSource('coquina', x: -1200, y: -800)
        ..add('electrolyzer', nodeId: 'elec', x: 0, y: 0)
        ..add('duplicant', nodeId: 'dupes', x: 3200, y: 1400)
        ..connectItem('elec', 'dupes', 'oxygen')
        ..pinCount('elec', 1))
      .build();

  Future<PipelineController> pumpCanvas(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: spreadOut());
    await tester.pumpWidget(harness(GraphCanvas(
      key: canvasKey,
      controller: controller,
      rateDisplay: RateDisplay.perSecond,
    )));
    // Frame the whole build, as a person would before reaching for a far node.
    canvasKey.currentState!.fitToContent();
    await tester.pump();
    return controller;
  }

  testWidgets('a node at negative coordinates can be selected', (tester) async {
    final controller = await pumpCanvas(tester);

    await tester.tap(find.text('Coquina supply'));
    await tester.pump();

    expect(controller.selectedNode?.id, 'src_coquina');
  });

  testWidgets('a node far past the window width can be selected',
      (tester) async {
    final controller = await pumpCanvas(tester);

    await tester.tap(find.text('Duplicant'));
    await tester.pump();

    expect(controller.selectedNode?.id, 'dupes');
  });

  testWidgets('the ports of a far node are clickable too', (tester) async {
    // The port dots sit inside the node, so whatever stopped the node being
    // hit stopped everything in it.
    final controller = await pumpCanvas(tester);
    final node = controller.pipeline.nodeOrThrow('dupes');
    final spec = controller.specOf(node);
    final world = NodeLayout.worldPortOffset(node, spec, 'oxygen');

    await tester.tapAt(canvasKey.currentState!.localFromWorld(world));
    await tester.pump();

    expect(find.byType(GraphCanvas), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a far node can be dragged, not merely selected',
      (tester) async {
    final controller = await pumpCanvas(tester);
    final before = controller.pipeline.nodeOrThrow('dupes').x;

    await tester.drag(find.text('Duplicant'), const Offset(60, 24));
    await tester.pump();

    expect(controller.pipeline.nodeOrThrow('dupes').x, isNot(before));
  });

  testWidgets('nodes near the origin still work, as they always did',
      (tester) async {
    final controller = await pumpCanvas(tester);
    await tester.tap(find.text('Electrolyzer'));
    await tester.pump();
    expect(controller.selectedNode?.id, 'elec');
  });
}
