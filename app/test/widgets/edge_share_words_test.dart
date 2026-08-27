import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// What a wire's share control says about the port it comes off.
///
/// Reported from a screenshot: "Taking everything the port makes, since
/// nothing else is asking for it", with two other wires asking for it. It
/// counted only the producer-driven ones.
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

  /// A generator's power going to an output, and optionally to consumers as
  /// well. The wire being inspected is always the one to the output.
  Pipeline power({required bool withConsumers}) {
    final b = PipelineBuilder(testDatabase, name: 'power')
      ..add('natural_gas_generator', nodeId: 'gen')
      ..addSink('power')
      ..connect('gen', 'power_out', 'sink_power', 'in', mode: EdgeMode.push)
      ..pinCount('gen', 1);
    if (withConsumers) {
      b
        ..add('rock_crusher_sand', nodeId: 'crusher')
        ..connect('gen', 'power_out', 'crusher', 'power_in');
    }
    return b.build();
  }

  Future<void> selectTheOutputWire(
      WidgetTester tester, PipelineController controller) async {
    controller.select(EdgeSelection(controller.pipeline.edges
        .firstWhere((e) => e.toNodeId == 'sink_power')
        .id));
    await tester.pumpAndSettle();
  }

  testWidgets('alone off a port, it takes everything', (tester) async {
    final controller = await pumpWith(tester, power(withConsumers: false));
    await selectTheOutputWire(tester, controller);

    expect(textContaining('nothing else is asking for it'), findsOneWidget);
  });

  testWidgets('and with a consumer beside it, it does not say that',
      (tester) async {
    // The consumer is a pull line, which is what used not to be counted.
    final controller = await pumpWith(tester, power(withConsumers: true));
    await selectTheOutputWire(tester, controller);

    expect(textContaining('nothing else is asking for it'), findsNothing);
    expect(textContaining('the other 1 line does not claim'), findsOneWidget);
  });
}
