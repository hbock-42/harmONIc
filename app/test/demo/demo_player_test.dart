import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/demo/demo.dart';
import 'package:oni_pipeline/demo/demo_bar.dart';
import 'package:oni_pipeline/demo/demo_player.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';

import '../support/harness.dart';

/// Playing a demo without eating what somebody was doing.
void main() {
  /// Three steps, each one a thing a person could have done.
  Demo threeSteps() => Demo(
        id: 'three',
        name: 'Three steps',
        summary: 'Water into oxygen.',
        steps: [
          const DemoStep(says: 'Nothing yet.'),
          DemoStep(
            says: 'A water supply.',
            does: (stage) => stage.remember('water',
                stage.controller.addNode('source:water', Offset.zero)),
          ),
          DemoStep(
            says: 'An Electrolyzer, fed from it.',
            does: (stage) => stage.controller.addNodeFor(
                PortRef(stage.nodeId('water'), 'out'), 'electrolyzer'),
          ),
        ],
      );

  late PipelineController controller;
  late WorkspaceController workspace;
  late DemoPlayer player;
  late List<void Function(Timer)> ticks;

  /// The clock is a seam, not a wait: a test that slept 2.6 seconds a step is
  /// a test nobody runs. Same trick as the guide's loader and the link opener.
  ///
  /// It has to honour cancel, or a paused demo goes on playing here while it
  /// stops everywhere else — which is exactly what the first version did.
  void tick() {
    for (final onTick in [...ticks]) {
      onTick(_StubTimer());
    }
  }

  setUp(() async {
    controller = testController(pipeline: testPipeline());
    workspace = await testWorkspace(controller);
    ticks = [];
    player = DemoPlayer(
      workspace: workspace,
      controller: controller,
      schedule: (_, onTick) {
        ticks.add(onTick);
        return _StubTimer(onCancel: () => ticks.remove(onTick));
      },
    );
    addTearDown(player.dispose);
  });

  test('it plays in a build of its own', () async {
    final mine = controller.pipeline.id;
    await player.start(threeSteps());

    expect(controller.pipeline.id, isNot(mine),
        reason: 'the demo did not open on top of what I was building');
    expect(controller.pipeline.nodes, isEmpty);
    expect(player.run!.says, 'Nothing yet.');
    expect(player.isPlaying, isTrue, reason: 'it starts playing');
  });

  test('and leaving puts your build back and takes the demo away', () async {
    final mine = controller.pipeline.id;
    await player.start(threeSteps());
    tick();
    tick();
    expect(controller.pipeline.nodes, isNotEmpty);

    await player.leave();

    expect(player.isRunning, isFalse);
    expect(player.isPlaying, isFalse);
    expect(controller.pipeline.id, mine, reason: 'back where I was');
    expect(controller.pipeline.nodes, hasLength(testPipeline().nodes.length),
        reason: 'and untouched');
    // Not merely closed: a build nobody made, left in the list, is litter.
    expect(workspace.saved.map((s) => s.name), isNot(contains('Three steps')));
  });

  test('the clock plays it a step at a time', () async {
    await player.start(threeSteps());
    expect(player.run!.played, 0);

    tick();
    expect(player.run!.played, 1);
    expect(player.run!.says, 'Nothing yet.');

    tick();
    expect(player.run!.played, 2);
    expect(controller.pipeline.nodes, hasLength(1));
  });

  test('pause stops it where it is, and play carries on', () async {
    await player.start(threeSteps());
    tick();
    player.pause();
    expect(player.isPlaying, isFalse);

    final where = player.run!.played;
    tick();
    expect(player.run!.played, where, reason: 'a paused demo does not move');

    player.play();
    tick();
    expect(player.run!.played, where + 1);
  });

  test('and you can walk it forward yourself', () async {
    await player.start(threeSteps());
    player.pause();

    player.step();
    player.step();

    expect(player.run!.played, 2);
    expect(controller.pipeline.nodes, hasLength(1));
  });

  test('the last step stops the clock', () async {
    // Rather than leaving a timer ticking over a demo with nothing left to
    // do, which is the sort of thing that keeps a test binding awake.
    await player.start(threeSteps());
    tick();
    tick();
    tick();

    expect(player.run!.isDone, isTrue);
    expect(player.isPlaying, isFalse);
    expect(controller.pipeline.edges, hasLength(1));
  });

  test('opening another build ends the demo rather than building into it',
      () async {
    // Reported by a probe rather than a person, and it threw: switch tabs
    // mid-demo and the next step wires a node to something that is not in
    // this pipeline. A demo owns a tab, and only while that tab is on screen.
    final mine = controller.pipeline.id;
    await player.start(threeSteps());
    tick();
    tick();
    expect(controller.pipeline.nodes, isNotEmpty);

    await workspace.open(mine);

    expect(player.isRunning, isFalse, reason: 'it let go');
    expect(player.isPlaying, isFalse);
    expect(controller.pipeline.id, mine);
    expect(controller.pipeline.nodes, hasLength(testPipeline().nodes.length),
        reason: 'and did not build into what I switched to');
    expect(workspace.saved.map((s) => s.name), isNot(contains('Three steps')));
  });

  test('starting another one does not leave the first behind', () async {
    await player.start(threeSteps());
    tick();
    await player.start(threeSteps());

    expect(player.run!.played, 0);
    expect(
        workspace.saved.where((s) => s.name == 'Three steps'), hasLength(1));
  });
  testWidgets('the bar says the line and takes the pace off the clock',
      (tester) async {
    await useDesktopSurface(tester);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: workspace,
      displaySettings: testDisplay(),
      demoPlayer: player,
    )));

    // Nothing playing, nothing in the way.
    expect(find.byType(DemoBar), findsOneWidget);
    expect(find.text('Leave'), findsNothing);

    await player.start(threeSteps());
    await tester.pumpAndSettle();
    expect(find.text('Nothing yet.'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

    // Somebody who reads faster than the clock does not have to wait for it.
    // Twice, because the line on screen is the one that has just happened and
    // the first step of this demo only talks.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('A water supply.'), findsOneWidget);
    expect(controller.pipeline.nodes, hasLength(1));

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('A water supply.'), findsNothing);
    expect(controller.pipeline.nodes, hasLength(testPipeline().nodes.length));
  });
}

/// A timer that never fires by itself; the test decides when.
class _StubTimer implements Timer {
  _StubTimer({this.onCancel});

  final void Function()? onCancel;
  bool _active = true;

  @override
  void cancel() {
    _active = false;
    onCancel?.call();
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}
