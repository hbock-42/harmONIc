import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/demo/demo.dart';
import 'package:oni_pipeline/demo/demos.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Every figure a demo says out loud, against what the app is showing when it
/// says it.
///
/// The demos exist to be believed, so a caption is a claim rather than a
/// caption. Three of them were wrong when this was first run — the bar prints
/// 1.40 kW and not 1 397 W, and two figures were narrated a step away from
/// where they were true. This is what stops that happening again the day a
/// recipe is corrected.
///
/// The rule is digits: a number written in figures must be a number the app is
/// showing. Numbers that are prose — "two clicks", "one for one", "thirty
/// nodes" — are written in words and left alone, which also makes a caption
/// say plainly which of its numbers it means as a claim.
void main() {
  /// Everything the app is showing right now, as numbers.
  ///
  /// Counts as solved and as built, how busy each thing is, what every
  /// boundary carries in grams and in kilograms, the totals along the bottom
  /// in their own units and in thousands — because a figure is quoted the way
  /// the screen prints it, and the screen changes unit above a thousand.
  Set<double> onScreen(PipelineController controller) {
    final shown = <double>{};
    void add(double value) {
      shown
        ..add(value)
        ..add(value.abs())
        ..add(value.abs() / 1000);
    }

    final solution = controller.solution;
    for (final node in controller.pipeline.nodes) {
      final result = solution.nodes[node.id];
      if (result == null) continue;
      add(result.count);
      add(result.wholeCount.toDouble());
      add((result.utilisation * 100).roundToDouble());
      add(result.powerWatts * result.count);
      add(result.heatKdtu * result.count);
    }
    for (final flow in solution.edgeFlows.values) {
      add(flow);
    }
    add(solution.netPowerWatts);
    add(solution.powerConsumedWatts);
    add(solution.powerGeneratedWatts);
    add(solution.totalHeatKdtu);
    add(solution.totalFootprintTiles.toDouble());
    return shown;
  }

  /// The figures a line claims, as written. Digits only, on purpose.
  ///
  /// Kept as text because how many decimals somebody wrote is the question:
  /// "1.40" is a claim about what the bar prints, and the bar prints two
  /// decimals. Comparing the raw 1 396.8 W with a tolerance let "1.39" through,
  /// which is exactly the kind of wrong figure this exists to catch.
  List<String> figuresIn(String says) => [
        for (final match in RegExp(r'\d+(?:\.\d+)?').allMatches(says))
          match.group(0)!,
      ];

  for (final demo in kDemos) {
    test('"${demo.name}" says only what the app is showing', () async {
      final controller = testController(
        pipeline: Pipeline(
            id: 'demo', name: 'Demo', nodes: const [], edges: const []),
      );
      final run = DemoRun(demo, controller);

      var checked = 0;
      while (await run.step()) {
        final shown = onScreen(controller);
        for (final claimed in figuresIn(run.says)) {
          checked++;
          // Rounded the way it was written: a figure quoted to two decimals
          // has to match what the screen prints to two decimals.
          final places = claimed.contains('.')
              ? claimed.length - claimed.indexOf('.') - 1
              : 0;
          expect(
            shown.any((value) => value.toStringAsFixed(places) == claimed),
            isTrue,
            reason: 'step ${run.played} of "${demo.name}" says $claimed, and '
                'nothing on screen prints that:\n  ${run.says}',
          );
        }
      }

      expect(checked, greaterThan(0),
          reason: 'a demo that claims no figures is a demo about nothing');
    });
  }

  test('and every demo ends somewhere the solver is happy with', () async {
    for (final demo in kDemos) {
      final controller = testController(
        pipeline: Pipeline(
            id: 'demo', name: 'Demo', nodes: const [], edges: const []),
      );
      await DemoRun(demo, controller).runToEnd();

      expect(controller.solution.status, SolveStatus.solved,
          reason: '"${demo.name}" ends on a build that does not solve');
      expect(controller.solution.issues.where((i) => i.isError), isEmpty,
          reason: '"${demo.name}" ends with a problem on screen');
    }
  });
  test('and no step of a demo leaves the build broken on screen', () async {
    // Underdetermined is fine and expected — nothing is pinned for the first
    // few steps — but a step that makes the build *impossible* would put a
    // red banner up mid-demo. The order matters and is easy to get wrong:
    // wiring the generator back into the Electrolyzer before its surplus has
    // anywhere to go is exactly the build that cannot balance.
    for (final demo in kDemos) {
      final controller = testController(
        pipeline: Pipeline(
            id: 'demo', name: 'Demo', nodes: const [], edges: const []),
      );
      final run = DemoRun(demo, controller);
      while (await run.step()) {
        expect(
          controller.solution.status,
          isNot(anyOf(SolveStatus.invalid, SolveStatus.inconsistent)),
          reason: 'step ${run.played} of "${demo.name}" breaks the build:\n'
              '  ${run.says}',
        );
      }
    }
  });

}
