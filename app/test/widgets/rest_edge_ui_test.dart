import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// "Whatever is left", as a thing somebody can pick.
void main() {
  Future<PipelineController> pumpWith(
    WidgetTester tester,
    Pipeline pipeline,
  ) async {
    await useDesktopSurface(tester);
    final controller = testController()..load(pipeline);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();
    return controller;
  }

  /// A generator powering a crusher, with the spare going to an output.
  Pipeline power(EdgeMode mode, {double gens = 1}) =>
      (PipelineBuilder(testDatabase, name: 'power')
        ..add('natural_gas_generator', nodeId: 'gen')
        ..add('rock_crusher_sand', nodeId: 'crusher')
        ..addSink('power')
        ..connect('gen', 'power_out', 'crusher', 'power_in')
        ..connect('gen', 'power_out', 'sink_power', 'in', mode: mode)
        ..pinCount('gen', gens)
        ..pinCount('crusher', 1))
      .build();

  testWidgets('the inspector offers it, and says what it means',
      (tester) async {
    final controller = await pumpWith(tester, power(EdgeMode.push));
    controller.select(const EdgeSelection('gen.power_out->sink_power.in'));
    await tester.pumpAndSettle();

    expect(find.text('Whatever is left'), findsWidgets);
    await tester.tap(find.text('Whatever is left').first);
    await tester.pumpAndSettle();

    final edge = controller.pipeline.edges
        .firstWhere((e) => e.toNodeId == 'sink_power');
    expect(edge.mode, EdgeMode.rest);
    expect(edge.share, isNull,
        reason: 'a share on a line that carries the rest is a number nothing '
            'reads');
    expect(textContaining('what is left of the producer'), findsOneWidget);
  });

  testWidgets('and the answer follows the others rather than a share',
      (tester) async {
    final controller = await pumpWith(tester, power(EdgeMode.rest));
    expect(controller.solution.status, SolveStatus.solved);
    expect(controller.solution.edgeFlows['gen.power_out->sink_power.in'],
        closeTo(800 - 240, 1e-6));

    // Double the generator and the surplus moves with it, untouched: no
    // share had to be worked out again, which is the whole point.
    controller.load(power(EdgeMode.rest, gens: 2));
    await tester.pumpAndSettle();
    expect(controller.solution.edgeFlows['gen.power_out->sink_power.in'],
        closeTo(1600 - 240, 1e-6));
    expect(
      controller.pipeline.edges
          .firstWhere((e) => e.toNodeId == 'sink_power')
          .share,
      isNull,
    );
  });
}
