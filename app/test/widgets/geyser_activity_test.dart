import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  /// A water geyser feeding electrolyzers — the shape of a real early base.
  Pipeline geyserPipeline() => (PipelineBuilder(testDatabase, name: 'Geyser fed')
        ..add('water_geyser', nodeId: 'geyser', x: 0, y: 100)
        ..add('electrolyzer', nodeId: 'elec', x: 320, y: 100)
        ..addSink('oxygen', x: 640, y: 60)
        ..addSink('hydrogen', x: 640, y: 240)
        ..connectItem('geyser', 'elec', 'water')
        ..connectItem('elec', 'sink_oxygen', 'oxygen')
        ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
        ..pinCount('geyser', 1))
      .build();

  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: geyserPipeline());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
    )));
    return controller;
  }

  testWidgets('the control only appears for geysers', (tester) async {
    final controller = await pumpEditor(tester);

    controller.select(const NodeSelection('elec'));
    await tester.pump();
    expect(find.text('ASSUME ACTIVE'), findsNothing);

    controller.select(const NodeSelection('geyser'));
    await tester.pump();
    expect(find.text('ASSUME ACTIVE'), findsOneWidget);
    expect(textContaining('40–80 %'), findsOneWidget);
  });

  testWidgets('worst case shrinks the whole build', (tester) async {
    final controller = await pumpEditor(tester);
    expect(controller.solution.nodes['elec']!.count, closeTo(1.8, 1e-9));

    controller.select(const NodeSelection('geyser'));
    await tester.pump();
    await tester.tap(find.textContaining('Worst'));
    await tester.pump();

    expect(controller.solution.nodes['elec']!.count,
        closeTo(1.8 * 2 / 3, 1e-9),
        reason: 'a 40 % geyser against a 60 % assumption');
    expect(controller.solution.status, SolveStatus.solved);
  });

  testWidgets('best case grows it', (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('geyser'));
    await tester.pump();
    await tester.tap(find.textContaining('Best'));
    await tester.pump();

    expect(controller.solution.nodes['elec']!.count,
        closeTo(1.8 * 4 / 3, 1e-9));
  });

  testWidgets('the chosen preset is shown as selected', (tester) async {
    final controller = await pumpEditor(tester);
    controller.setNodeActivity('geyser', GeyserActivity.minimumActiveFraction);
    controller.select(const NodeSelection('geyser'));
    await tester.pump();

    expect(controller.activityOf(controller.pipeline.nodeOrThrow('geyser')),
        closeTo(0.4, 1e-9));
  });

  testWidgets('the top bar swings every geyser at once, in one undo step',
      (tester) async {
    final controller = await pumpEditor(tester);
    final before = controller.solution.nodes['elec']!.count;

    expect(find.text('ALL GEYSERS'), findsOneWidget);
    await tester.tap(find.widgetWithText(GestureDetector, '40%').first);
    await tester.pump();

    expect(controller.solution.nodes['elec']!.count, lessThan(before));

    controller.undo();
    expect(controller.solution.nodes['elec']!.count, closeTo(before, 1e-9));
  });

  testWidgets('a pipeline without geysers hides the top-bar control',
      (tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
    )));

    expect(find.text('ALL GEYSERS'), findsNothing);
  });

  testWidgets('the assumption is saved with the pipeline', (tester) async {
    final controller = await pumpEditor(tester);
    controller.setNodeActivity('geyser', GeyserActivity.minimumActiveFraction);
    await tester.pumpAndSettle();

    final restored = Pipeline.fromJson(controller.pipeline.toJson());
    expect(restored.nodeOrThrow('geyser').outputScale,
        closeTo(GeyserActivity.scaleFor(0.4), 1e-9));
  });
}
