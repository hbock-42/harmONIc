import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/canvas/port_menu.dart';
import 'package:oni_pipeline/demo/demo_cursor.dart';
import 'package:oni_pipeline/demo/demo_player.dart';
import 'package:oni_pipeline/demo/demos.dart';
import 'package:oni_pipeline/demo/widget_hands.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// A demo on a screen does what a person does.
///
/// Reported twice, and the second time after a highlight had been added:
/// "it just builds like magic". It did — a step was a call on the controller,
/// so nothing was ever clicked and the highlight was a caption on a magic
/// trick. These are the tests for the thing that was actually missing.
void main() {
  late PipelineController controller;
  late DemoPlayer player;
  late WidgetHands hands;

  Future<void> pump(WidgetTester tester) async {
    await useDesktopSurface(tester);
    controller = testController(
      pipeline:
          Pipeline(id: 'blank', name: 'Blank', nodes: const [], edges: const []),
    );
    final workspace = await testWorkspace(controller);
    final canvasKey = GlobalKey<GraphCanvasState>();
    hands = WidgetHands(
      canvas: canvasKey,
      rowKeys: {},
      search: TextEditingController(),
      // The cursor still travels, or there is nothing to watch; it just
      // travels in a hurry here.
      travel: const Duration(milliseconds: 10),
      dwell: const Duration(milliseconds: 10),
    );
    addTearDown(hands.dispose);
    player = DemoPlayer(
      workspace: workspace,
      controller: controller,
      hands: hands,
      schedule: (_, _) => Timer(Duration.zero, () {}),
    );
    addTearDown(player.dispose);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: workspace,
      displaySettings: testDisplay(),
      demoPlayer: player,
      demoHands: hands,
      canvasKey: canvasKey,
    )));
    await tester.pumpAndSettle();
  }

  /// Play one step and let the clock run.
  ///
  /// A step is a Future that waits on timers now, and under `flutter_test`
  /// the clock only moves when the test pumps — so awaiting the step without
  /// pumping is a deadlock, and awaiting it *after* pumping is the whole
  /// trick.
  Future<void> playOne(WidgetTester tester) async {
    final done = player.step();
    await tester.pumpAndSettle();
    await done;
  }

  testWidgets('the cursor goes to the palette row before anything is placed',
      (tester) async {
    await pump(tester);
    await player.start(whatAGeyserFeeds);
    await tester.pumpAndSettle();

    final stepping = player.step();
    // Mid-step: the row is lit, the cursor is out, and nothing has been
    // placed yet. Cause before effect is the whole of what was missing.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5));
    expect(hands.litSpec, 'water_geyser');
    // It searched for it first, because the row is otherwise below the fold
    // and a cursor cannot point at what is not on screen.
    expect(hands.search.text, 'Water Geyser');
    await tester.pump(const Duration(milliseconds: 20));
    expect(hands.cursor, isNotNull);
    expect(controller.pipeline.nodes, isEmpty,
        reason: 'it placed the node before showing where the click was');
    expect(find.byType(DemoCursor), findsOneWidget);

    await tester.pumpAndSettle();
    await stepping;
    expect(controller.pipeline.nodes, hasLength(1));
    expect(hands.cursor, isNull, reason: 'and it puts the cursor away after');
  });

  testWidgets('and a wire is asked for through the real port menu',
      (tester) async {
    await pump(tester);
    await player.start(whatAGeyserFeeds);
    await tester.pumpAndSettle();
    await playOne(tester);

    final wiring = player.step();
    // The dot first.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5));
    expect(hands.litPort?.portId, 'water');
    expect(find.byType(PortMenu), findsNothing);

    // Then the menu somebody would have opened, with the recipe about to be
    // chosen lit in it.
    await tester.pump(const Duration(milliseconds: 30));
    expect(find.byType(PortMenu), findsOneWidget,
        reason: 'the wire appeared without the menu ever opening');
    expect(hands.litSpec, 'electrolyzer');

    await tester.pumpAndSettle();
    await wiring;
    expect(find.byType(PortMenu), findsNothing);
    expect(controller.pipeline.edges, hasLength(1));
  });

  testWidgets('and the whole demo still ends where it should', (tester) async {
    await pump(tester);
    await player.start(whatAGeyserFeeds);
    await tester.pumpAndSettle();
    while (!player.run!.isDone) {
      await playOne(tester);
    }

    // The same build the headless run produces, made by clicking instead.
    expect(controller.pipeline.nodes, hasLength(5));
    expect(controller.solution.status, SolveStatus.solved);
    expect(controller.solution.netPowerWatts, closeTo(1396.8, 0.1));
  });
}
