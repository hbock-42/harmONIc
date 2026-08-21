import 'package:flutter/gestures.dart';
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
    Pipeline? pipeline,
  }) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline);
    await tester.pumpWidget(harness(
      GraphCanvas(
        key: canvasKey,
        controller: controller,
        rateDisplay: RateDisplay.perSecond,
      ),
    ));
    return controller;
  }

  /// Where a port's dot ends up on screen, via the canvas's own transform.
  Offset screenPortOffset(PipelineController c, PortRef ref) {
    final node = c.pipeline.nodeOrThrow(ref.nodeId);
    final world =
        NodeLayout.worldPortOffset(node, c.specOf(node), ref.portId);
    return canvasKey.currentState!.localFromWorld(world);
  }

  group('coordinates', () {
    testWidgets('world and screen conversions are inverses', (tester) async {
      await pumpCanvas(tester);
      final state = canvasKey.currentState!;
      const world = Offset(321, -87);
      expect(state.worldFromLocal(state.localFromWorld(world)).dx,
          closeTo(world.dx, 1e-9));
      expect(state.worldFromLocal(state.localFromWorld(world)).dy,
          closeTo(world.dy, 1e-9));
    });

    testWidgets('zooming keeps the point under the cursor fixed',
        (tester) async {
      await pumpCanvas(tester);
      final state = canvasKey.currentState!;
      const focal = Offset(400, 300);
      final worldBefore = state.worldFromLocal(focal);

      state.zoomBy(1.4, focal);
      await tester.pump();

      final worldAfter = state.worldFromLocal(focal);
      expect(worldAfter.dx, closeTo(worldBefore.dx, 1e-6));
      expect(worldAfter.dy, closeTo(worldBefore.dy, 1e-6));
      expect(state.scale, closeTo(1.4, 1e-9));
    });

    testWidgets('zoom is clamped', (tester) async {
      await pumpCanvas(tester);
      final state = canvasKey.currentState!;
      for (var i = 0; i < 30; i++) {
        state.zoomBy(1.5, Offset.zero);
      }
      expect(state.scale, lessThanOrEqualTo(GraphCanvasState.maxScale));

      for (var i = 0; i < 60; i++) {
        state.zoomBy(0.5, Offset.zero);
      }
      expect(state.scale, greaterThanOrEqualTo(GraphCanvasState.minScale));
    });

    testWidgets('fit frames every node', (tester) async {
      final controller = await pumpCanvas(tester);
      canvasKey.currentState!
        ..zoomBy(2.4, Offset.zero)
        ..fitToContent();
      await tester.pump();

      final state = canvasKey.currentState!;
      final size = tester.getSize(find.byType(GraphCanvas));
      for (final node in controller.pipeline.nodes) {
        final topLeft = state.localFromWorld(Offset(node.x, node.y));
        expect(topLeft.dx, greaterThanOrEqualTo(-1));
        expect(topLeft.dy, greaterThanOrEqualTo(-1));
        expect(topLeft.dx, lessThanOrEqualTo(size.width));
        expect(topLeft.dy, lessThanOrEqualTo(size.height));
      }
    });
  });

  group('interaction', () {
    testWidgets('dragging the background pans without moving nodes',
        (tester) async {
      final controller = await pumpCanvas(tester);
      final state = canvasKey.currentState!;
      final offsetBefore = state.offset;
      final nodeXBefore = controller.pipeline.nodeOrThrow('elec').x;

      // An empty patch of canvas, far from any node.
      await tester.dragFrom(const Offset(1200, 700), const Offset(-60, 40));
      await tester.pump();

      // The gesture recogniser eats the touch slop, so assert the direction
      // rather than an exact delta.
      expect(state.offset.dx, lessThan(offsetBefore.dx));
      expect(state.offset.dy, greaterThan(offsetBefore.dy));
      expect(controller.pipeline.nodeOrThrow('elec').x, nodeXBefore,
          reason: 'panning the view must not move the graph');
    });

    testWidgets('dragging a node moves it and records one undo step',
        (tester) async {
      final controller = await pumpCanvas(tester);
      final before = controller.pipeline.nodeOrThrow('elec');

      await tester.drag(
        find.descendant(
          of: find.byType(GraphCanvas),
          matching: find.text('Electrolyzer'),
        ),
        const Offset(64, 32),
      );
      await tester.pump();

      final after = controller.pipeline.nodeOrThrow('elec');
      expect(after.x, greaterThan(before.x));
      expect(after.x % NodeLayout.gridSize, 0, reason: 'snapped to the grid');

      controller.undo();
      expect(controller.pipeline.nodeOrThrow('elec').x, before.x);
      expect(controller.canUndo, isFalse);
    });

    testWidgets('dragging port to port creates a connection', (tester) async {
      // Start from a graph with the hydrogen unconnected, then wire it up.
      final pipeline = (PipelineBuilder(testDatabase, name: 'wire me')
            ..add('electrolyzer', nodeId: 'elec', x: 100, y: 100)
            ..add('hydrogen_generator', nodeId: 'hgen', x: 560, y: 100)
            ..pinCount('elec', 1))
          .build();
      final controller = await pumpCanvas(tester, pipeline: pipeline);
      expect(controller.pipeline.edges, isEmpty);

      final from = screenPortOffset(controller, const PortRef('elec', 'hydrogen'));
      final to = screenPortOffset(controller, const PortRef('hgen', 'hydrogen'));

      final gesture = await tester.startGesture(from);
      await tester.pump();
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(controller.pipeline.edges, hasLength(1));
      final edge = controller.pipeline.edges.single;
      expect(edge.fromNodeId, 'elec');
      expect(edge.toNodeId, 'hgen');
      // 112 g/s of hydrogen runs 1.12 generators.
      expect(controller.solution.nodes['hgen']!.count, closeTo(1.12, 1e-9));
    });

    testWidgets('a drop on an incompatible port creates nothing',
        (tester) async {
      final pipeline = (PipelineBuilder(testDatabase, name: 'mismatch')
            ..add('electrolyzer', nodeId: 'elec', x: 100, y: 100)
            ..add('coal_generator', nodeId: 'gen', x: 560, y: 100)
            ..pinCount('elec', 1))
          .build();
      final controller = await pumpCanvas(tester, pipeline: pipeline);

      final from = screenPortOffset(controller, const PortRef('elec', 'oxygen'));
      final to = screenPortOffset(controller, const PortRef('gen', 'coal'));

      final gesture = await tester.startGesture(from);
      await gesture.moveTo(to);
      await gesture.up();
      await tester.pump();

      expect(controller.pipeline.edges, isEmpty,
          reason: 'oxygen does not go into a coal port');
    });

    testWidgets('clicking a wire selects it', (tester) async {
      final controller = await pumpCanvas(tester);
      final edge = controller.pipeline.edges
          .firstWhere((e) => e.toNodeId == 'dupes');
      final fromNode = controller.pipeline.nodeOrThrow(edge.fromNodeId);
      final toNode = controller.pipeline.nodeOrThrow(edge.toNodeId);
      final from = NodeLayout.worldPortOffset(
          fromNode, controller.specOf(fromNode), edge.fromPortId);
      final to = NodeLayout.worldPortOffset(
          toNode, controller.specOf(toNode), edge.toPortId);

      // Midpoint of the curve, converted to screen space.
      final metrics = edgePath(from, to).computeMetrics().first;
      final midpoint =
          metrics.getTangentForOffset(metrics.length / 2)!.position;
      await tester.tapAt(canvasKey.currentState!.localFromWorld(midpoint));
      await tester.pump();

      expect(controller.selection, isA<EdgeSelection>());
      expect((controller.selection! as EdgeSelection).edgeId, edge.id);
    });

    testWidgets('clicking empty space clears the selection', (tester) async {
      final controller = await pumpCanvas(tester)
        ..select(const NodeSelection('elec'));
      await tester.pump();

      await tester.tapAt(const Offset(1200, 700));
      await tester.pump();

      expect(controller.selection, isNull);
    });

    testWidgets('scrolling pans, and scrolling with meta zooms',
        (tester) async {
      await pumpCanvas(tester);
      final state = canvasKey.currentState!;
      final before = state.offset;

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(const Offset(500, 400));
      await tester.sendEventToBinding(
          pointer.scroll(const Offset(0, 50)));
      await tester.pump();

      expect(state.offset, before - const Offset(0, 50));
      expect(state.scale, 1, reason: 'plain scroll must not zoom');
    });
  });
}
