import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/demo/demo.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// The engine a demo is played by.
void main() {
  /// A demo small enough to check by hand: a water supply, an Electrolyzer,
  /// and ten kilograms a second of water going in.
  Demo aLittleOne() => const Demo(
        id: 'test',
        name: 'A little one',
        summary: 'Water into oxygen.',
        steps: [
          DemoStep(says: 'Start with nothing.'),
          DemoStep(
            says: 'Place a water supply.',
            does: PlaceFromPalette('source:water', remember: 'water'),
          ),
          DemoStep(
            says: 'And an Electrolyzer, fed from it.',
            does: ClickPortAndPick(
              node: 'water',
              portId: sourcePortId,
              pick: 'electrolyzer',
              remember: 'elec',
            ),
          ),
          DemoStep(
            says: 'Ten kilograms of water a second.',
            does:
                PinAmount(node: 'water', portId: sourcePortId, rate: 10000),
          ),
        ],
      );

  PipelineController emptyController() => testController(
        pipeline: Pipeline(
            id: 'demo', name: 'Demo', nodes: const [], edges: const []),
      );

  test('a step is a thing somebody could have done', () async {
    final controller = emptyController();
    final run = DemoRun(aLittleOne(), controller);

    expect(run.played, 0);
    expect(run.says, 'Start with nothing.');
    expect(controller.pipeline.nodes, isEmpty);

    await run.runToEnd();

    expect(run.isDone, isTrue);
    expect(controller.pipeline.nodes, hasLength(2));
    expect(controller.pipeline.edges, hasLength(1));
  });

  test('and the numbers come out of the solver, not out of the demo',
      () async {
    // The whole reason this drives the real controller. Ten kilograms of
    // water a second is ten Electrolyzers, because one drinks a kilogram.
    final controller = emptyController();
    await DemoRun(aLittleOne(), controller).runToEnd();

    final elec = controller.pipeline.nodes
        .firstWhere((n) => n.specId == 'electrolyzer');
    expect(controller.solution.nodes[elec.id]!.count, closeTo(10, 1e-6));
    expect(controller.solution.status, SolveStatus.solved);
  });

  test('stepping through gets to the same place as running to the end',
      () async {
    // A property worth keeping: the test that checks a demo's figures runs it
    // one way and a person watching runs it the other.
    final watched = emptyController();
    final run = DemoRun(aLittleOne(), watched);
    var guard = 0;
    while (await run.step()) {
      expect(guard++, lessThan(100));
    }

    final hurried = emptyController();
    await DemoRun(aLittleOne(), hurried).runToEnd();

    expect(jsonEncode(watched.pipeline.toJson()), jsonEncode(hurried.pipeline.toJson()));
  });

  test('what it is saying is the step that has just happened', () async {
    final run = DemoRun(aLittleOne(), emptyController());

    // Before anything, the first line — there is something to read while the
    // player is still on its opening pause.
    expect(run.says, 'Start with nothing.');

    await run.step();
    expect(run.says, 'Start with nothing.');

    await run.step();
    expect(run.says, 'Place a water supply.');

    await run.runToEnd();
    expect(run.says, 'Ten kilograms of water a second.');
  });

  test('an empty demo is over before it starts', () async {
    final run = DemoRun(
      const Demo(id: 'nothing', name: 'Nothing', summary: '', steps: []),
      emptyController(),
    );

    expect(run.isDone, isTrue);
    expect(await run.step(), isFalse);
    expect(run.says, isEmpty);
  });
  test('and a demo asking for something it never made says so', () async {
    // Loudly, because the test that runs every demo is the only thing between
    // a broken one and somebody watching it break.
    final run = DemoRun(
      const Demo(
        id: 'muddled',
        name: 'Muddled',
        summary: '',
        steps: [
          DemoStep(
            says: 'Wire up the geyser nobody placed.',
            does: ClickPortAndPick(
              node: 'geyser',
              portId: 'water',
              pick: 'electrolyzer',
              remember: 'elec',
            ),
          ),
        ],
      ),
      emptyController(),
    );

    await expectLater(run.step(), throwsA(isA<StateError>()));
  });

}
