import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  final canvasKey = GlobalKey<GraphCanvasState>();

  Future<PipelineController> pumpCanvas(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(GraphCanvas(
      key: canvasKey,
      controller: controller,
      rateDisplay: RateDisplay.perSecond,
      onToggleRates: () {},
    )));
    return controller;
  }

  Offset worldOf(PipelineController c, String id) {
    final node = c.pipeline.nodeOrThrow(id);
    return Offset(node.x, node.y);
  }

  group('the step it takes', () {
    const viewport = Size(1200, 800);

    test('is nothing at all in the middle', () {
      expect(GraphCanvasState.edgePanFor(const Offset(600, 400), viewport),
          Offset.zero);
    });

    test('grows the further into the margin the pointer comes', () {
      final near = GraphCanvasState.edgePanFor(const Offset(60, 400), viewport);
      final hard = GraphCanvasState.edgePanFor(const Offset(4, 400), viewport);
      expect(near.dx, greaterThan(0), reason: 'left edge pulls the view right');
      expect(hard.dx, greaterThan(near.dx));
      expect(near.dy, 0);
    });

    test('points the other way at the other edge, and stops at the wall', () {
      final right =
          GraphCanvasState.edgePanFor(const Offset(1200, 400), viewport);
      expect(right.dx, lessThan(0));
      // Past the edge is not faster than against it: a pointer dragged out of
      // the window should not fling the canvas.
      final outside =
          GraphCanvasState.edgePanFor(const Offset(1400, 400), viewport);
      expect(outside.dx, right.dx);
    });

    test('takes both axes in a corner', () {
      final corner = GraphCanvasState.edgePanFor(const Offset(10, 790), viewport);
      expect(corner.dx, greaterThan(0));
      expect(corner.dy, lessThan(0));
    });
  });

  testWidgets('a node held at the edge keeps moving, and so does the view',
      (tester) async {
    final controller = await pumpCanvas(tester);
    final before = worldOf(controller, 'elec');
    final viewBefore = canvasKey.currentState!.offset;

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Electrolyzer')));
    // Out to the right-hand edge and then held perfectly still, which is the
    // case that used to do nothing: no pointer movement, no drag update.
    await gesture.moveTo(const Offset(1430, 400));
    await tester.pump();
    final afterMove = worldOf(controller, 'elec');
    await tester.pump(const Duration(milliseconds: 200));

    expect(canvasKey.currentState!.offset.dx,
        lessThan(viewBefore.dx), reason: 'the view should follow the drag');
    expect(worldOf(controller, 'elec').dx, greaterThan(afterMove.dx),
        reason: 'and the node should keep going with it');
    expect(afterMove.dx, greaterThan(before.dx));

    await gesture.up();
    await tester.pump();
  });

  testWidgets('a rubber band reaching the edge drags the view with it',
      (tester) async {
    await pumpCanvas(tester);
    final viewBefore = canvasKey.currentState!.offset;

    // Shift turns a background drag into a selection band.
    final from = canvasKey.currentState!.localFromWorld(const Offset(-40, 40));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(const Offset(1000, 400));
    await tester.pump();
    await gesture.moveTo(const Offset(1430, 400));
    await tester.pump(const Duration(milliseconds: 200));

    expect(canvasKey.currentState!.offset.dx, lessThan(viewBefore.dx));

    await gesture.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  });

  testWidgets('letting go stops it', (tester) async {
    final controller = await pumpCanvas(tester);

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Electrolyzer')));
    await gesture.moveTo(const Offset(1430, 400));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();

    final settled = canvasKey.currentState!.offset;
    final node = worldOf(controller, 'elec');
    await tester.pump(const Duration(milliseconds: 300));

    expect(canvasKey.currentState!.offset, settled);
    expect(worldOf(controller, 'elec'), node);
  });

  testWidgets('a drag that stays in the middle moves nothing but the node',
      (tester) async {
    await pumpCanvas(tester);
    final viewBefore = canvasKey.currentState!.offset;

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Electrolyzer')));
    await gesture.moveTo(const Offset(720, 460));
    await tester.pump(const Duration(milliseconds: 200));

    expect(canvasKey.currentState!.offset, viewBefore);

    await gesture.up();
    await tester.pump();
  });
}
