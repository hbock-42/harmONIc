import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Changing which recipe a building runs, without placing it again.
void main() {
  /// An Aquatuner on water, cooling something, with a turbine over it.
  Pipeline loop() => (PipelineBuilder(testDatabase, name: 'Loop')
        ..addSource('heat')
        ..addSource('water')
        ..add('aquatuner_water', nodeId: 'tuner', x: 300, y: 200)
        ..add('steam_turbine', nodeId: 'turbine', x: 700, y: 200)
        ..connectItem('src_heat', 'tuner', 'heat')
        ..connectItem('src_water', 'tuner', 'water')
        ..connect('tuner', 'heat_out', 'turbine', 'heat_in')
        ..pinCount('turbine', 1))
      .build();

  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: loop());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    controller.select(const NodeSelection('tuner'));
    await tester.pumpAndSettle();
    return controller;
  }

  test('a building knows what else it runs', () {
    final db = testDatabase;
    final variants = db.variantsOf(db.processOrThrow('aquatuner_water'));
    expect(variants.length, greaterThan(10), reason: 'one per coolant');
    expect(variants.map((s) => s.name), contains('Aquatuner (Petroleum)'));
    // A machine with one recipe has no variants to offer.
    expect(db.variantsOf(db.processOrThrow('electrolyzer')), isEmpty);
  });

  testWidgets('the coolant can be changed on the node', (tester) async {
    final controller = await pumpEditor(tester);
    // Named by what differs, since every one of them starts "Aquatuner (".
    expect(find.text('AQUATUNER —'), findsOneWidget);
    await tester.ensureVisible(find.text('Petroleum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petroleum'));
    await tester.pumpAndSettle();

    expect(controller.pipeline.nodeOrThrow('tuner').specId,
        'aquatuner_petroleum');
    // The node stayed where it was, and the heat wire survived: petroleum
    // moves less heat, so the build needs more of them.
    expect(controller.pipeline.nodeOrThrow('tuner').x, 300);
    // Petroleum moves less heat a second than water, so the same turbine
    // needs more machines under it: 3.56 rather than 1.5.
    expect(controller.solution.nodes['tuner']!.count, closeTo(3.56, 0.01));
    // The water supply is loose now — it fed a machine that no longer drinks
    // water — so the build says it needs an amount rather than pretending.
    expect(controller.solution.status, SolveStatus.underdetermined);
  });

  testWidgets('and the wire that no longer fits comes off, and is said',
      (tester) async {
    final controller = await pumpEditor(tester);
    expect(controller.pipeline.edges, hasLength(3));

    await tester.ensureVisible(find.text('Petroleum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petroleum'));
    await tester.pumpAndSettle();

    // The water supply cannot feed a petroleum machine.
    expect(controller.pipeline.edges, hasLength(2));
    expect(textContaining('did not fit'), findsOneWidget);
  });

  testWidgets('and undo puts the whole thing back', (tester) async {
    final controller = await pumpEditor(tester);
    await tester.ensureVisible(find.text('Petroleum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petroleum'));
    await tester.pumpAndSettle();

    controller.undo();
    await tester.pumpAndSettle();

    expect(controller.pipeline.nodeOrThrow('tuner').specId, 'aquatuner_water');
    expect(controller.pipeline.edges, hasLength(3),
        reason: 'one swap is one step back, wires included');
  });
}
