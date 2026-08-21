import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  /// A hatch ranch fed by a coal-hungry generator downstream.
  Pipeline ranch() => (PipelineBuilder(testDatabase, name: 'Hatch ranch')
        ..add('hatch', nodeId: 'hatches', x: 0, y: 100)
        ..add('coal_generator', nodeId: 'gen', x: 340, y: 100)
        ..addSink('egg', x: 340, y: 300)
        ..connectItem('hatches', 'gen', 'coal')
        ..connectItem('hatches', 'sink_egg', 'egg')
        ..pinCount('hatches', 12))
      .build();

  Future<PipelineController> pumpEditor(
    WidgetTester tester, {
    Pipeline? pipeline,
  }) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline ?? ranch());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  testWidgets('a ranch reports the Duplicant time it costs', (tester) async {
    final controller = await pumpEditor(tester);

    // 12 hatches × 12 s of grooming = 144 s a cycle.
    expect(controller.solution.dupeLabourSecondsPerCycle, closeTo(144, 1e-6));
    expect(find.text('DUPE TIME'), findsOneWidget);
    expect(textContaining('144 s'), findsOneWidget);
    expect(textContaining('0.24 dupes'), findsOneWidget);
  });

  testWidgets('a pipeline with no labour hides the figure', (tester) async {
    await pumpEditor(tester, pipeline: testPipeline());
    expect(find.text('DUPE TIME'), findsNothing);
  });

  testWidgets('a ranch that eats a whole Duplicant is flagged',
      (tester) async {
    final controller = await pumpEditor(tester);
    controller.pin(const BuildingCountPin(nodeId: 'hatches', count: 60));
    await tester.pump();

    // 60 hatches is 720 s a cycle — more than one Duplicant has.
    expect(controller.solution.dupeLabourSecondsPerCycle, closeTo(720, 1e-6));
    expect(textContaining('1.20 dupes'), findsOneWidget);
  });

  testWidgets('eggs flow out of the ranch', (tester) async {
    final controller = await pumpEditor(tester);
    // One egg per hatch every 6 cycles.
    // Stored to 6 decimal places of eggs per second, hence the tolerance.
    expect(controller.solution.nodes['sink_egg']!.count,
        closeTo(12 / (6 * secondsPerCycle), 1e-5));
  });

  testWidgets('the coal the hatches make sizes the generator', (tester) async {
    final controller = await pumpEditor(tester);
    // 12 hatches make 12 × 116.67 g/s; a generator eats 1000 g/s.
    expect(controller.solution.nodes['gen']!.count,
        closeTo(12 * 70000 / secondsPerCycle / 1000, 1e-3));
  });

  testWidgets('an ungroomed ranch says it needs stabling', (tester) async {
    final controller = await pumpEditor(tester);
    // Nothing supplies grooming yet, so it shows up as something to provide.
    expect(controller.solution.externalInputs['grooming'], closeTo(12, 1e-6));
  });

  testWidgets('adding a station covers the critters and sizes itself',
      (tester) async {
    final controller = await pumpEditor(tester);
    final stationId =
        controller.addNode('grooming_station', const Offset(-300, 100));
    controller.connect(
      PortRef(stationId, 'grooming'),
      const PortRef('hatches', 'grooming'),
    );
    await tester.pump();

    expect(controller.solution.externalInputs['grooming'], isNull,
        reason: 'the stable covers them now');
    // Twelve hatches at eight to a stable.
    expect(controller.solution.nodes[stationId]!.count, closeTo(12 / 8, 1e-9));
    expect(controller.solution.nodes[stationId]!.wholeCount, 2);
  });

  testWidgets('a station does not double-charge the grooming time',
      (tester) async {
    final controller = await pumpEditor(tester);
    final before = controller.solution.dupeLabourSecondsPerCycle;

    final stationId =
        controller.addNode('grooming_station', const Offset(-300, 100));
    controller.connect(
      PortRef(stationId, 'grooming'),
      const PortRef('hatches', 'grooming'),
    );
    await tester.pump();

    expect(controller.solution.dupeLabourSecondsPerCycle, closeTo(before, 1e-6),
        reason: 'the labour is booked on the critters, once');
  });

  testWidgets('the inspector shows a critter its own grooming cost',
      (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('hatches'));
    await tester.pump();

    expect(find.text('DUPE TIME'), findsNWidgets(2),
        reason: 'once in the summary bar, once for the selected ranch');
    expect(textContaining('144 s/cycle'), findsOneWidget);
  });
}
