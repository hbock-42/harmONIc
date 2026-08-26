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
    while (run.played < 7) {
      await run.step();
    }

    expect(controller.solution.status, SolveStatus.solved);
    expect(ironOut(controller), closeTo(6666.67, 0.01));
    expect(asShown(controller, ironOut(controller)), '6.67 kg/s');
    expect(run.says, contains('6.67 kg/s'));
    expect(controller.pipeline.edges.every((e) => e.share == null), isTrue,
        reason: 'nobody has set a share yet');
  });

  test('and asking for the best gets half as much again', () async {
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
    final controller = blank();
    await DemoRun(letItChooseTheSplit, controller).runToEnd();

    final shares = controller.pipeline.edges.map((e) => e.share).toList();
    expect(shares, everyElement(isNotNull));
    expect(shares.where((s) => s == 1.0), hasLength(2));
    expect(shares.where((s) => s == 0.0), hasLength(2));
  });

  test('it is the same ore either way', () async {
    // The comparison the demo makes rests on this: nothing about the supply
    // changed between the even split and the chosen one.
    final controller = blank();
    final run = DemoRun(letItChooseTheSplit, controller);
    while (run.played < 7) {
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
