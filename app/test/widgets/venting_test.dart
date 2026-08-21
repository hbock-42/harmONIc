import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  /// A geyser and a fixed crew: two pins that only agree if the spare oxygen
  /// is allowed to go somewhere.
  Pipeline geyserAndCrew() =>
      (PipelineBuilder(testDatabase, name: 'Geyser and crew')
            ..add('water_geyser', nodeId: 'geyser', x: 0, y: 100)
            ..add('electrolyzer', nodeId: 'elec', x: 320, y: 100)
            ..add('duplicant', nodeId: 'dupes', x: 640, y: 60)
            ..addSink('hydrogen', x: 640, y: 280)
            ..connectItem('geyser', 'elec', 'water')
            ..connectItem('elec', 'dupes', 'oxygen')
            ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
            ..pinCount('geyser', 1))
          .build();

  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: geyserAndCrew());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  testWidgets('two pins that disagree are explained, not just rejected',
      (tester) async {
    final controller = await pumpEditor(tester);
    controller.pin(const BuildingCountPin(nodeId: 'geyser', count: 1));
    // Pinning the crew as well over-constrains the oxygen port.
    controller.load(controller.pipeline.copyWith(pins: [
      const BuildingCountPin(nodeId: 'geyser', count: 1),
      const BuildingCountPin(nodeId: 'dupes', count: 12),
    ]));
    await tester.pump();

    expect(controller.solution.status, SolveStatus.inconsistent);
    expect(textContaining('venting'), findsWidgets,
        reason: 'the banner should name the way out');
  });

  testWidgets('the vent button only appears where it would change something',
      (tester) async {
    final controller = await pumpEditor(tester);

    controller.select(const NodeSelection('elec'));
    await tester.pump();
    // Oxygen and hydrogen are both pulled, so both can vent; water is an input.
    expect(find.descendant(
      of: find.byType(InspectorPanel),
      matching: find.text('vent'),
    ), findsNWidgets(2));

    controller.select(const NodeSelection('geyser'));
    await tester.pump();
    // A geyser's description is long enough to push PORTS below the fold, and
    // the panel builds lazily, so scroll to it as a person would.
    await tester.drag(find.byType(InspectorPanel), const Offset(0, -400));
    await tester.pump();

    // The geyser's water is pulled by the Electrolyzer, so it can vent too.
    expect(find.descendant(
      of: find.byType(InspectorPanel),
      matching: find.text('vent'),
    ), findsOneWidget);
  });

  testWidgets('venting resolves the contradiction and reports the leftover',
      (tester) async {
    final controller = await pumpEditor(tester);
    controller.load(controller.pipeline.copyWith(pins: [
      const BuildingCountPin(nodeId: 'geyser', count: 1),
      const BuildingCountPin(nodeId: 'dupes', count: 12),
    ]));
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    await tester.tap(find.descendant(
      of: find.byType(InspectorPanel),
      matching: find.text('vent'),
    ).first);
    await tester.pump();

    expect(controller.solution.status, SolveStatus.solved);
    expect(controller.solution.nodes['elec']!.count, closeTo(1.8, 1e-9));
    expect(controller.solution.nodes['dupes']!.count, closeTo(12, 1e-9));
    // 1.8 Electrolyzers make 1598.4 g/s; twelve dupes breathe 1200.
    expect(controller.solution.externalOutputs['oxygen'],
        closeTo(1.8 * 888 - 1200, 1e-6));
  });

  testWidgets('the button says which state it is in', (tester) async {
    final controller = await pumpEditor(tester);
    controller.setPortVenting('elec', 'oxygen', venting: true);
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    expect(find.text('venting'), findsOneWidget);
    expect(controller.pipeline.nodeOrThrow('elec').ventsPort('oxygen'), isTrue);
  });

  testWidgets('venting is saved with the pipeline', (tester) async {
    final controller = await pumpEditor(tester);
    controller.setPortVenting('elec', 'oxygen', venting: true);
    await tester.pumpAndSettle();

    final restored = Pipeline.fromJson(controller.pipeline.toJson());
    expect(restored.nodeOrThrow('elec').ventedPorts, {'oxygen'});
  });
}
