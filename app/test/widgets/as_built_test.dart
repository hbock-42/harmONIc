import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  Future<PipelineController> pumpEditor(
    WidgetTester tester,
    Pipeline pipeline,
  ) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  /// A ranch sized by the generator it feeds, which lands on a fraction of a
  /// Hatch — the only interesting case.
  Pipeline ranch() => (PipelineBuilder(testDatabase, name: 'Ranch')
        ..add('hatch', nodeId: 'hatches', x: 0, y: 100)
        ..add('coal_generator', nodeId: 'gen', x: 340, y: 100)
        ..connectItem('hatches', 'gen', 'coal')
        ..pinCount('gen', 1))
      .build();

  testWidgets('a rounded-up critter says what the spare one eats',
      (tester) async {
    final controller = await pumpEditor(tester, ranch());
    controller.select(const NodeSelection('hatches'));
    await tester.pump();

    expect(textContaining('does not idle'), findsOneWidget);
    expect(textContaining('makes'), findsWidgets);
    expect(textContaining('more coal'), findsOneWidget);
    expect(textContaining('more sedimentary rock'), findsOneWidget);
  });

  testWidgets('a machine idles instead, so it says nothing', (tester) async {
    final controller = await pumpEditor(tester, ranch());
    controller.select(const NodeSelection('gen'));
    await tester.pump();

    expect(textContaining('does not idle'), findsNothing);
  });

  testWidgets('a whole number of critters needs no warning', (tester) async {
    final whole = (PipelineBuilder(testDatabase, name: 'Ranch')
          ..add('hatch', nodeId: 'hatches', x: 0, y: 100)
          ..pinCount('hatches', 8))
        .build();
    final controller = await pumpEditor(tester, whole);
    controller.select(const NodeSelection('hatches'));
    await tester.pump();

    expect(textContaining('does not idle'), findsNothing);
  });
}
