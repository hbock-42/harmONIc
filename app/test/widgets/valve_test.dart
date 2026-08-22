import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Putting a valve on a line, and being told when the build outgrows it.
void main() {
  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final pipeline = (PipelineBuilder(testDatabase, name: 'Ore')
          ..addSource('iron_ore', x: 0, y: 0)
          ..add('metal_refinery', nodeId: 'refinery', x: 340, y: 0)
          ..add('rock_crusher_metal', nodeId: 'crusher', x: 340, y: 260)
          ..addSink('iron', x: 680, y: 120)
          ..connectItem('src_iron_ore', 'refinery', 'iron_ore')
          ..connectItem('src_iron_ore', 'crusher', 'iron_ore')
          ..connectItem('refinery', 'sink_iron', 'refined_metal')
          ..connectItem('crusher', 'sink_iron', 'refined_metal')
          ..pinRate('src_iron_ore', sourcePortId, 10000))
        .build();
    final controller = testController(pipeline: pipeline);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  Future<void> selectRefineryLine(
      WidgetTester tester, PipelineController controller) async {
    final line = controller.pipeline.edges
        .firstWhere((e) => e.toNodeId == 'refinery');
    controller.select(EdgeSelection(line.id));
    await tester.pumpAndSettle();
  }

  testWidgets('a wire can be given one, and it is remembered', (tester) async {
    final controller = await pumpEditor(tester);
    await selectRefineryLine(tester, controller);

    await tester.ensureVisible(find.byKey(valveFieldKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(valveFieldKey), '1000');
    await tester.pumpAndSettle();

    final line = controller.pipeline.edges
        .firstWhere((e) => e.toNodeId == 'refinery');
    expect(line.capPerSecond, 1000);
  });

  testWidgets('and the build says when it has outgrown it', (tester) async {
    final controller = await pumpEditor(tester);
    await selectRefineryLine(tester, controller);
    await tester.ensureVisible(find.byKey(valveFieldKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(valveFieldKey), '1000');
    await tester.pumpAndSettle();

    // The line has to carry 3.33 kg/s. The figures do not change — they are
    // what the build needs — but somebody is told.
    expect(controller.solution.status, SolveStatus.solved);
    expect(
      controller.solution.issues.where((i) => i.message.contains('valve')),
      hasLength(1),
    );
    expect(textContaining('valve'), findsWidgets);
  });

  testWidgets('emptying the field takes it off again', (tester) async {
    final controller = await pumpEditor(tester);
    await selectRefineryLine(tester, controller);
    await tester.ensureVisible(find.byKey(valveFieldKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(valveFieldKey), '1000');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(valveFieldKey), '');
    await tester.pumpAndSettle();

    expect(
        controller.pipeline.edges
            .firstWhere((e) => e.toNodeId == 'refinery')
            .capPerSecond,
        isNull);
    expect(controller.solution.issues.where((i) => i.message.contains('valve')),
        isEmpty);
  });

  testWidgets('and asking for the most works inside it', (tester) async {
    final controller = await pumpEditor(tester);
    await selectRefineryLine(tester, controller);
    await tester.ensureVisible(find.byKey(valveFieldKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(valveFieldKey), '4000');
    await tester.pumpAndSettle();

    controller.select(const NodeSelection('sink_iron'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Get as much as possible'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get as much as possible'));
    await tester.pumpAndSettle();

    // Four through the refinery and six through the crusher at half yield.
    // Without the valve it would have been ten.
    expect(controller.solution.nodes['sink_iron']!.count, closeTo(7000, 1e-6));
    // And nothing complains, because the answer respects the valve rather
    // than being warned about afterwards.
    expect(controller.solution.issues.where((i) => i.message.contains('valve')),
        isEmpty);
  });
}
