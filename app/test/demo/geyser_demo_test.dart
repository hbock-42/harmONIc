import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/demo/demo.dart';
import 'package:oni_pipeline/demo/demos.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// "What a geyser feeds", and the figures it claims.
void main() {
  PipelineController play(Demo demo) {
    final controller = testController(
      pipeline:
          Pipeline(id: 'demo', name: 'Demo', nodes: const [], edges: const []),
    );
    DemoRun(demo, controller).runToEnd();
    return controller;
  }

  double countOf(PipelineController controller, String specId) {
    final node =
        controller.pipeline.nodes.firstWhere((n) => n.specId == specId);
    return controller.solution.nodes[node.id]!.count;
  }

  test('it builds the SPOM, and the solver agrees it works', () {
    final controller = play(whatAGeyserFeeds);

    expect(controller.solution.status, SolveStatus.solved);
    expect(controller.solution.issues.where((i) => i.isError), isEmpty);
    expect(controller.pipeline.nodes, hasLength(5));
  });

  test('and the numbers it narrates are the ones on screen', () {
    // Read off the demo as it runs, not typed in from the wiki. When a recipe
    // changes, this fails and the narration is what has to be corrected —
    // which is the whole reason the demo drives the real controller.
    final controller = play(whatAGeyserFeeds);
    final said = whatAGeyserFeeds.steps.map((s) => s.says).join(' ');

    // "one geyser"
    expect(countOf(controller, 'water_geyser'), closeTo(1, 1e-6));

    // "sixteen Duplicants" — 15.98 of them, and you build sixteen.
    final dupes = countOf(controller, 'duplicant');
    expect(dupes, closeTo(15.98, 0.01));
    expect(dupes.ceil(), 16);
    expect(said, contains('sixteen Duplicants'));

    // "two Electrolyzers of which one idles a tenth of the time"
    final elec = countOf(controller, 'electrolyzer');
    expect(elec, closeTo(1.80, 0.01));
    expect(elec.ceil(), 2);
    expect((elec / elec.ceil() * 100).round(), 90);

    // "1.40 kW spare", which is what the bottom bar prints for 1396.8 W.
    expect(controller.solution.netPowerWatts, closeTo(1396.8, 0.1));
    final power = controller.database.itemOrThrow(WellKnownItems.power);
    expect(
        power.formatRate(
            controller.solution.netPowerWatts, RateDisplay.perSecond),
        '1.40 kW');
    expect(said, contains('1.40 kW'));
  });

  test('and it really is red before the generator goes in', () {
    // The moment the demo is built around: the build costs power until the
    // hydrogen has somewhere to burn.
    final controller = testController(
      pipeline:
          Pipeline(id: 'demo', name: 'Demo', nodes: const [], edges: const []),
    );
    final run = DemoRun(whatAGeyserFeeds, controller);
    while (run.played < 6) {
      run.step();
    }

    expect(controller.solution.netPowerWatts, closeTo(-216, 0.1));
    expect(run.says, contains('216 W'));
  });
}
