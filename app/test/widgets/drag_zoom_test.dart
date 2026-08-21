import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/geometry.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  final canvasKey = GlobalKey<GraphCanvasState>();

  Future<PipelineController> pumpCanvas(
    WidgetTester tester, {
    double scale = 1,
  }) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(GraphCanvas(
      key: canvasKey,
      controller: controller,
      rateDisplay: RateDisplay.perSecond,
    )));
    if (scale != 1) {
      // Zoom about the node under test so it stays on screen; zooming about
      // the middle would carry it out of the window and out of reach.
      final state = canvasKey.currentState!;
      state.zoomBy(scale, state.localFromWorld(const Offset(300, 100)));
      await tester.pump();
    }
    return controller;
  }

  Offset worldOf(PipelineController c, String id) {
    final node = c.pipeline.nodeOrThrow(id);
    return Offset(node.x, node.y);
  }

  group('a dragged card stays under the pointer', () {
    for (final scale in [0.5, 1.0, 2.0]) {
      testWidgets('at ${(scale * 100).toStringAsFixed(0)} %', (tester) async {
        final controller = await pumpCanvas(tester, scale: scale);
        final before = worldOf(controller, 'elec');
        const drag = Offset(120, 64);

        await tester.drag(find.text('Electrolyzer'), drag);
        await tester.pump();

        // A pointer moving 120 screen pixels at half zoom has crossed 240 of
        // the graph's own units; the card must cross the same. Grid snapping
        // allows a cell of slack.
        final moved = worldOf(controller, 'elec') - before;
        expect(moved.dx, closeTo(drag.dx / scale, NodeLayout.gridSize + 0.001));
        expect(moved.dy, closeTo(drag.dy / scale, NodeLayout.gridSize + 0.001));
      });
    }
  });

  testWidgets('many small movements are not lost to the grid', (tester) async {
    // Snapping each frame throws away whatever did not reach a grid line, so a
    // slow drag — or any drag when zoomed out — used to move nothing at all.
    final controller = await pumpCanvas(tester, scale: 0.5);
    final before = controller.pipeline.nodeOrThrow('elec').x;

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Electrolyzer')));
    for (var i = 0; i < 40; i++) {
      await gesture.moveBy(const Offset(3, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    // 120 screen pixels at half zoom is 240 world units.
    expect(controller.pipeline.nodeOrThrow('elec').x - before,
        closeTo(240, NodeLayout.gridSize));
  });

  testWidgets('a group keeps its shape while being dragged', (tester) async {
    final controller = await pumpCanvas(tester, scale: 2);
    controller.selectNodes(['elec', 'dupes']);
    await tester.pump();
    final gap = controller.pipeline.nodeOrThrow('dupes').x -
        controller.pipeline.nodeOrThrow('elec').x;

    await tester.drag(find.text('Electrolyzer'), const Offset(80, 40));
    await tester.pump();

    expect(
      controller.pipeline.nodeOrThrow('dupes').x -
          controller.pipeline.nodeOrThrow('elec').x,
      gap,
    );
  });
}
