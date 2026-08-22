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
    expect(textContaining('more raw mineral'), findsOneWidget);
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

  testWidgets('the bar says what the rounding costs the whole build',
      (tester) async {
    // The node says what the spare Hatch costs where it stands. This is the
    // other question: what must I actually supply? The figures beside it are
    // the exact ratio, and a critter that cannot idle makes the ratio an
    // understatement.
    final controller = await pumpEditor(tester, ranch());
    final report = controller.asBuiltReport;
    expect(report.roundedUp, isNotEmpty);
    expect(report.drifts, isNotEmpty);

    expect(find.text('AS BUILT'), findsOneWidget);
    // Worst first: the extra Hatch eats raw mineral it was not counted for.
    expect(textContaining('Raw Mineral'), findsWidgets);
  });

  testWidgets('and says nothing of the kind when nothing was rounded',
      (tester) async {
    // Machines idle, so a build of machines lands exactly where the ratio put
    // it and there is nothing to report.
    final exact = (PipelineBuilder(testDatabase, name: 'Exact')
          ..addSource('water', x: 0, y: 0)
          ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
          ..connectItem('src_water', 'elec', 'water')
          ..pinCount('elec', 2.5))
        .build();
    final controller = await pumpEditor(tester, exact);

    expect(controller.asBuiltReport.isExact, isTrue);
    expect(find.text('AS BUILT'), findsNothing);
  });
}
