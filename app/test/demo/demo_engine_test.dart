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
  Demo aLittleOne() => Demo(
        id: 'test',
        name: 'A little one',
        summary: 'Water into oxygen.',
        steps: [
          const DemoStep(says: 'Start with nothing.'),
          DemoStep(
            says: 'Place a water supply.',
            does: (stage) => stage.remember('water',
                stage.controller.addNode('source:water', const Offset(0, 0))),
          ),
          DemoStep(
            says: 'And an Electrolyzer, fed from it.',
            does: (stage) {
              final id = stage.controller.addNodeFor(
                  PortRef(stage.nodeId('water'), 'out'), 'electrolyzer');
              stage.controller.select(NodeSelection(stage.remember('elec', id!)));
            },
          ),
          DemoStep(
            says: 'Ten kilograms of water a second.',
            does: (stage) => stage.controller.pin(PortRatePin(
                nodeId: stage.nodeId('water'),
                portId: 'out',
                ratePerSecond: 10000)),
          ),
        ],
      );

  PipelineController emptyController() => testController(
        pipeline: Pipeline(
            id: 'demo', name: 'Demo', nodes: const [], edges: const []),
      );

  test('a step is a thing somebody could have done', () {
    final controller = emptyController();
    final run = DemoRun(aLittleOne(), controller);

    expect(run.played, 0);
    expect(run.says, 'Start with nothing.');
    expect(controller.pipeline.nodes, isEmpty);

    run.runToEnd();

    expect(run.isDone, isTrue);
    expect(controller.pipeline.nodes, hasLength(2));
    expect(controller.pipeline.edges, hasLength(1));
  });

  test('and the numbers come out of the solver, not out of the demo', () {
    // The whole reason this drives the real controller. Ten kilograms of
    // water a second is ten Electrolyzers, because one drinks a kilogram.
    final controller = emptyController();
    DemoRun(aLittleOne(), controller).runToEnd();

    final elec = controller.pipeline.nodes
        .firstWhere((n) => n.specId == 'electrolyzer');
    expect(controller.solution.nodes[elec.id]!.count, closeTo(10, 1e-6));
    expect(controller.solution.status, SolveStatus.solved);
  });

  test('stepping through gets to the same place as running to the end', () {
    // A property worth keeping: the test that checks a demo's figures runs it
    // one way and a person watching runs it the other.
    final watched = emptyController();
    final run = DemoRun(aLittleOne(), watched);
    var guard = 0;
    while (run.step()) {
      expect(guard++, lessThan(100));
    }

    final hurried = emptyController();
    DemoRun(aLittleOne(), hurried).runToEnd();

    expect(jsonEncode(watched.pipeline.toJson()), jsonEncode(hurried.pipeline.toJson()));
  });

  test('what it is saying is the step that has just happened', () {
    final run = DemoRun(aLittleOne(), emptyController());

    // Before anything, the first line — there is something to read while the
    // player is still on its opening pause.
    expect(run.says, 'Start with nothing.');

    run.step();
    expect(run.says, 'Start with nothing.');

    run.step();
    expect(run.says, 'Place a water supply.');

    run.runToEnd();
    expect(run.says, 'Ten kilograms of water a second.');
  });

  test('an empty demo is over before it starts', () {
    final run = DemoRun(
      const Demo(id: 'nothing', name: 'Nothing', summary: '', steps: []),
      emptyController(),
    );

    expect(run.isDone, isTrue);
    expect(run.step(), isFalse);
    expect(run.says, isEmpty);
  });
  test('and a demo asking for something it never made says so', () {
    // Loudly, because the test that runs every demo is the only thing between
    // a broken one and somebody watching it break.
    final run = DemoRun(
      Demo(
        id: 'muddled',
        name: 'Muddled',
        summary: '',
        steps: [
          DemoStep(
            says: 'Wire up the geyser nobody placed.',
            does: (stage) => stage.nodeId('geyser'),
          ),
        ],
      ),
      emptyController(),
    );

    expect(run.step, throwsA(isA<StateError>()));
  });

}
