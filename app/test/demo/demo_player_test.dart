import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/demo/demo.dart';
import 'package:oni_pipeline/demo/demo_player.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';

import '../support/harness.dart';

/// Playing a demo without eating what somebody was doing.
void main() {
  /// Three steps, each one a thing a person could have done.
  Demo threeSteps() => const Demo(
        id: 'three',
        name: 'Three steps',
        summary: 'Water into oxygen.',
        steps: [
          DemoStep(says: 'Nothing yet.'),
          DemoStep(
            says: 'A water supply.',
            does: PlaceFromPalette('source:water', remember: 'water'),
          ),
          DemoStep(
            says: 'An Electrolyzer, fed from it.',
            does: ClickPortAndPick(
              node: 'water',
              portId: sourcePortId,
              pick: 'electrolyzer',
              remember: 'elec',
            ),
          ),
        ],
      );

  late PipelineController controller;
  late WorkspaceController workspace;
  late DemoPlayer player;

  setUp(() async {
    controller = testController(pipeline: testPipeline());
    workspace = await testWorkspace(controller);
    player = DemoPlayer(workspace: workspace, controller: controller);
    addTearDown(player.dispose);
  });

  test('it plays in a build of its own', () async {
    final mine = controller.pipeline.id;
    await player.start(threeSteps());

    expect(controller.pipeline.id, isNot(mine),
        reason: 'the demo did not open on top of what I was building');
    expect(controller.pipeline.nodes, isEmpty);
    // Nothing happens until somebody presses Next: a demo that plays itself
    // is a video, and you look away to read a number and it has moved on.
    expect(player.run!.played, 0);
    expect(player.run!.nextSays, 'Nothing yet.');
  });

  test('and each press does one thing', () async {
    await player.start(threeSteps());

    await player.step();
    expect(player.run!.played, 1);
    expect(controller.pipeline.nodes, isEmpty, reason: 'the first only talks');

    await player.step();
    expect(controller.pipeline.nodes, hasLength(1));

    await player.step();
    expect(controller.pipeline.edges, hasLength(1));
    expect(player.run!.isDone, isTrue);
  });

  test('and the words are about what has not happened yet', () async {
    // The whole reason they moved next to the cursor: they say where to look
    // before anything moves.
    await player.start(threeSteps());
    expect(player.run!.nextSays, 'Nothing yet.');

    await player.step();
    expect(player.run!.nextSays, 'A water supply.');
    expect(controller.pipeline.nodes, isEmpty);

    await player.step();
    expect(player.run!.nextSays, 'An Electrolyzer, fed from it.');
  });

  test('leaving puts your build back and takes the demo away', () async {
    final mine = controller.pipeline.id;
    await player.start(threeSteps());
    await player.step();
    await player.step();
    expect(controller.pipeline.nodes, isNotEmpty);

    await player.leave();

    expect(player.isRunning, isFalse);
    expect(controller.pipeline.id, mine, reason: 'back where I was');
    expect(controller.pipeline.nodes, hasLength(testPipeline().nodes.length),
        reason: 'and untouched');
    // Not merely closed: a build nobody made, left in the list, is litter.
    expect(workspace.saved.map((s) => s.name), isNot(contains('Three steps')));
  });

  test('opening another build ends the demo rather than building into it',
      () async {
    // It threw, before this: switch tabs mid-demo and the next step wires a
    // node to something that is not in this pipeline.
    final mine = controller.pipeline.id;
    await player.start(threeSteps());
    await player.step();
    await player.step();

    await workspace.open(mine);

    expect(player.isRunning, isFalse, reason: 'it let go');
    expect(controller.pipeline.id, mine);
    expect(controller.pipeline.nodes, hasLength(testPipeline().nodes.length),
        reason: 'and did not build into what I switched to');
    expect(workspace.saved.map((s) => s.name), isNot(contains('Three steps')));
  });

  test('starting another one does not leave the first behind', () async {
    await player.start(threeSteps());
    await player.step();
    await player.start(threeSteps());

    expect(player.run!.played, 0);
    expect(
        workspace.saved.where((s) => s.name == 'Three steps'), hasLength(1));
  });
}
