import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/geometry.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/canvas/minimap.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  final canvasKey = GlobalKey<GraphCanvasState>();

  Pipeline spreadOut() => (PipelineBuilder(testDatabase, name: 'Spread')
        ..add('electrolyzer', nodeId: 'elec', x: 0, y: 0)
        ..add('coal_generator', nodeId: 'far', x: 6000, y: 4000)
        ..pinCount('elec', 1))
      .build();

  Future<PipelineController> pumpCanvas(
    WidgetTester tester, {
    Pipeline? pipeline,
  }) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline ?? spreadOut());
    await tester.pumpWidget(harness(GraphCanvas(
      key: canvasKey,
      controller: controller,
      rateDisplay: RateDisplay.perSecond,
      onToggleRates: () {},
    )));
    return controller;
  }

  bool isVisible(PipelineController c, String id) {
    final node = c.pipeline.nodeOrThrow(id);
    final size = NodeLayout.sizeOf(c.specOf(node));
    return canvasKey.currentState!.visibleWorldRect
        .overlaps(Offset(node.x, node.y) & size);
  }

  testWidgets('it appears once there is something to map', (tester) async {
    await pumpCanvas(tester);
    expect(find.byType(Minimap), findsOneWidget);
  });

  testWidgets('an empty build has no map', (tester) async {
    await useDesktopSurface(tester);
    final controller = PipelineController(testDatabase);
    await tester.pumpWidget(harness(GraphCanvas(
      key: canvasKey,
      controller: controller,
      rateDisplay: RateDisplay.perSecond,
      onToggleRates: () {},
    )));

    expect(find.byType(Minimap), findsNothing);
  });

  testWidgets('clicking it travels to that part of the build', (tester) async {
    final controller = await pumpCanvas(tester);
    expect(isVisible(controller, 'far'), isFalse);

    // The far node is bottom-right of the build, so its corner of the map is.
    final map = tester.getRect(find.byType(Minimap));
    await tester.tapAt(Offset(map.right - 24, map.bottom - 20));
    await tester.pump();

    expect(isVisible(controller, 'far'), isTrue);
    expect(isVisible(controller, 'elec'), isFalse,
        reason: 'it really moved, rather than zooming out to show everything');
  });

  testWidgets('dragging across it scrubs the view', (tester) async {
    await pumpCanvas(tester);
    final map = tester.getRect(find.byType(Minimap));

    await tester.dragFrom(map.center, const Offset(60, 40));
    await tester.pump();

    expect(canvasKey.currentState!.offset, isNot(const Offset(120, 100)));
    expect(canvasKey.currentState!.scale, 1, reason: 'travelling is not zooming');
  });

  testWidgets('the window marker follows the view', (tester) async {
    final controller = await pumpCanvas(tester);
    final before = canvasKey.currentState!.visibleWorldRect;

    canvasKey.currentState!.centreOn(const Offset(6000, 4000));
    await tester.pump();

    expect(canvasKey.currentState!.visibleWorldRect, isNot(before));
    expect(isVisible(controller, 'far'), isTrue);
  });

  testWidgets('zooming out shows a larger window on the map', (tester) async {
    await pumpCanvas(tester);
    final before = canvasKey.currentState!.visibleWorldRect;

    canvasKey.currentState!.zoomAtCentre(0.5);
    await tester.pump();

    expect(canvasKey.currentState!.visibleWorldRect.width,
        greaterThan(before.width));
  });
}
