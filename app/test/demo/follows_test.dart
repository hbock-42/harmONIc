import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/geometry.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/demo/demo_player.dart';
import 'package:oni_pipeline/demo/demos.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// A demo that builds off the edge of the screen is a demo nobody can watch.
void main() {
  late PipelineController controller;
  late DemoPlayer player;

  Future<void> pump(WidgetTester tester) async {
    await useDesktopSurface(tester);
    controller = testController(
      pipeline:
          Pipeline(id: 'blank', name: 'Blank', nodes: const [], edges: const []),
    );
    final workspace = await testWorkspace(controller);
    player = DemoPlayer(
      workspace: workspace,
      controller: controller,
      schedule: (_, _) => Timer(Duration.zero, () {}),
    );
    addTearDown(player.dispose);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: workspace,
      displaySettings: testDisplay(),
      demoPlayer: player,
    )));
    await tester.pumpAndSettle();
  }

  /// Every node's own rectangle, in the canvas's own coordinates.
  List<Rect> onScreen(WidgetTester tester) {
    final state = tester.state<GraphCanvasState>(find.byType(GraphCanvas));
    return [
      for (final node in controller.pipeline.nodes)
        () {
          final world = NodeLayout.worldRect(node, controller.specOf(node));
          final topLeft = state.localFromWorld(world.topLeft);
          final bottomRight = state.localFromWorld(world.bottomRight);
          return Rect.fromPoints(topLeft, bottomRight);
        }(),
    ];
  }

  testWidgets('the view follows what the demo is building', (tester) async {
    await pump(tester);
    await player.start(whatAGeyserFeeds);
    await tester.pumpAndSettle();

    // Play it out, and check after every step that nothing it has placed is
    // off the edge. The finished build is 1 152 px wide — wider than the
    // canvas at any window this is used at — so without the view following,
    // the last things it places happen where nobody can see them.
    while (!player.run!.isDone) {
      player.step();
      await tester.pumpAndSettle();
      if (controller.pipeline.nodes.isEmpty) continue;

      final canvas = tester.getRect(find.byType(GraphCanvas));
      for (final rect in onScreen(tester)) {
        expect(rect.left, greaterThanOrEqualTo(-1),
            reason: 'a node is off the left at step ${player.run!.played}');
        expect(rect.right, lessThanOrEqualTo(canvas.width + 1),
            reason: 'a node is off the right at step ${player.run!.played}');
        expect(rect.top, greaterThanOrEqualTo(-1));
        expect(rect.bottom, lessThanOrEqualTo(canvas.height + 1));
      }
    }
  });

  testWidgets('and it does not zoom about when nothing is playing',
      (tester) async {
    // Placing a node reveals it — that is the canvas's own behaviour and
    // predates this — but nothing should be *fitting* the view when there is
    // no demo running, because a fit changes the zoom under somebody.
    await pump(tester);
    controller.addNode('electrolyzer', Offset.zero);
    await tester.pumpAndSettle();
    final state = tester.state<GraphCanvasState>(find.byType(GraphCanvas));
    final scale = state.scale;

    controller.addNode('water_geyser', const Offset(2000, 2000));
    await tester.pumpAndSettle();

    expect(state.scale, scale,
        reason: 'the view zoomed on its own with no demo running');
  });

  testWidgets('a fit lands even if the view is mid-glide', (tester) async {
    // Revealing a node animates the offset, and an animation in flight goes
    // on writing to it. A fit that landed mid-glide used to be undone a frame
    // later — which is every step of a demo, since placing a node selects it
    // and selecting one reveals it.
    await pump(tester);
    controller.addNode('electrolyzer', const Offset(4000, 4000));
    await tester.pump();
    final state = tester.state<GraphCanvasState>(find.byType(GraphCanvas));

    state.fitToContent();
    await tester.pumpAndSettle();

    final node = controller.pipeline.nodes.single;
    final rect = NodeLayout.worldRect(node, controller.specOf(node));
    final canvas = tester.getRect(find.byType(GraphCanvas));
    final topLeft = state.localFromWorld(rect.topLeft);
    expect(topLeft.dx, greaterThanOrEqualTo(-1));
    expect(topLeft.dx, lessThanOrEqualTo(canvas.width));
  });
}
