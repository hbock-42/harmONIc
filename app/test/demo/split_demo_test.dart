import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/demo/demo.dart';
import 'package:oni_pipeline/demo/demos.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// "Let it choose the split", and the figures it claims.
void main() {
  PipelineController blank() => testController(
        pipeline:
            Pipeline(id: 'demo', name: 'Demo', nodes: const [], edges: const []),
      );

  double ironOut(PipelineController controller) {
    final sink =
        controller.pipeline.nodes.firstWhere((n) => n.specId == 'sink:iron');
    return controller.solution.nodes[sink.id]!.count;
  }

  String asShown(PipelineController controller, double gramsPerSecond) =>
      controller.database
          .itemOrThrow('iron')
          .formatRate(gramsPerSecond, RateDisplay.perSecond);

  test('an even split is what you get for saying nothing', () async {
    // The step the demo is built around: seven lines in, before anybody has
    // asked for anything, the ore divides equally because nobody said.
    final controller = blank();
    final run = DemoRun(letItChooseTheSplit, controller);
    while (run.played < 8) {
      await run.step();
    }

    expect(controller.solution.status, SolveStatus.solved);
    expect(ironOut(controller), closeTo(7500, 0.01));
    expect(asShown(controller, ironOut(controller)), '7.50 kg/s');
    expect(run.says, contains('7.50 kg/s'));
    expect(controller.pipeline.edges.every((e) => e.share == null), isTrue,
        reason: 'nobody has set a share yet');
  });

  test('and the ore really does divide evenly, which it did not use to',
      () async {
    // The demo said the app "split the ore evenly" while the ore went 3.33 to
    // the refinery and 6.67 to the crusher. What was even was the *iron*, held
    // there by two consumer-driven lines into one output node -- the very
    // shape somebody reported as resources quietly going negative, sitting in
    // the app's own tutorial and described backwards. The demo says the
    // producer decides now, which is what makes the sentence true.
    final controller = blank();
    final run = DemoRun(letItChooseTheSplit, controller);
    while (run.played < 8) {
      await run.step();
    }

    double flow(String toSpecId) {
      final edge = controller.pipeline.edges.firstWhere((e) =>
          controller.pipeline.nodeOrThrow(e.toNodeId).specId == toSpecId &&
          controller.pipeline.nodeOrThrow(e.fromNodeId).specId ==
              'source:iron_ore');
      return controller.solution.edgeFlows[edge.id]!;
    }

    expect(flow('metal_refinery'), closeTo(5000, 0.01));
    expect(flow('rock_crusher_metal'), closeTo(5000, 0.01));
    expect(run.says, contains('Five kilograms of ore to each'));
  });

  test('and asking for the best gets a third more', () async {
    final controller = blank();
    await DemoRun(letItChooseTheSplit, controller).runToEnd();

    expect(ironOut(controller), closeTo(10000, 1e-6));
    expect(asShown(controller, ironOut(controller)), '10.00 kg/s');
    expect(
        letItChooseTheSplit.steps.map((s) => s.says).join(' '),
        contains('10.00 kg/s'));
  });

  test('and what it chose is on the wires, as ordinary shares', () async {
    // The claim in the last line. Everything to the refinery, nothing to the
    // crusher — written back as numbers somebody could have typed, which is
    // why the ordinary solver still produces every figure on screen.
    //
    // "Nothing to the crusher" is a wire left alone rather than a wire set to
    // zero. A share of zero locks a wire shut, and a locked wire broke a
    // player's build: an outlet the answer did not need could never be used
    // again. An unshared wire takes what is left, and here nothing is.
    final controller = blank();
    await DemoRun(letItChooseTheSplit, controller).runToEnd();

    final shares = controller.pipeline.edges.map((e) => e.share).toList();
    expect(shares.where((s) => s == 1.0), hasLength(2),
        reason: 'everything down the refinery line');
    expect(shares.where((s) => s == null), hasLength(2));

    // And nothing is what those two carry, which is the part that matters.
    final flows = controller.solution.edgeFlows;
    for (final edge in controller.pipeline.edges) {
      if (edge.share != null) continue;
      expect(flows[edge.id], closeTo(0, 1e-9), reason: edge.id);
    }
  });

  test('it is the same ore either way', () async {
    // The comparison the demo makes rests on this: nothing about the supply
    // changed between the even split and the chosen one.
    final controller = blank();
    final run = DemoRun(letItChooseTheSplit, controller);
    while (run.played < 8) {
      await run.step();
    }
    final ore = controller.pipeline.nodes
        .firstWhere((n) => n.specId == 'source:iron_ore');
    final before = controller.solution.nodes[ore.id]!.count;

    await run.runToEnd();

    expect(controller.solution.nodes[ore.id]!.count, closeTo(before, 1e-6));
    expect(before, closeTo(10000, 1e-6));
  });
}
