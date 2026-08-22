import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Asking the app for the most it can do.
void main() {
  Future<PipelineController> pumpEditor(
      WidgetTester tester, Pipeline pipeline) async {
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

  /// 10 kg/s of ore, and two ways to turn it into metal.
  Pipeline twoWays() => (PipelineBuilder(testDatabase, name: 'Ore')
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

  /// One supply, one consumer: nothing is divided.
  Pipeline oneWay() => (PipelineBuilder(testDatabase, name: 'Plain')
        ..addSource('water', x: 0, y: 0)
        ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
        ..addSink('oxygen', x: 680, y: 0)
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'sink_oxygen', 'oxygen')
        ..pinRate('src_water', sourcePortId, 1000))
      .build();

  testWidgets('an output node offers it when something is divided',
      (tester) async {
    final controller = await pumpEditor(tester, twoWays());
    expect(controller.solution.nodes['sink_iron']!.count,
        closeTo(6666.67, 0.01));

    controller.select(const NodeSelection('sink_iron'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Get as much as possible'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get as much as possible'));
    await tester.pumpAndSettle();

    // Everything through the refinery: half the metal again.
    expect(controller.solution.nodes['sink_iron']!.count,
        closeTo(10000, 1e-6));
    expect(controller.solution.nodes['crusher']!.count, closeTo(0, 1e-6));
    expect(textContaining('Divided to give'), findsOneWidget);
  });

  testWidgets('and undo puts the splits back', (tester) async {
    final controller = await pumpEditor(tester, twoWays());
    controller.select(const NodeSelection('sink_iron'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Get as much as possible'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get as much as possible'));
    await tester.pumpAndSettle();

    controller.undo();
    await tester.pumpAndSettle();

    expect(controller.solution.nodes['sink_iron']!.count,
        closeTo(6666.67, 0.01));
    expect(controller.pipeline.edges.every((e) => e.share == null), isTrue);
  });

  testWidgets('with nothing divided, it is not offered', (tester) async {
    // There would be nothing to choose, and a button that does nothing is
    // worse than no button.
    final controller = await pumpEditor(tester, oneWay());
    controller.select(const NodeSelection('sink_oxygen'));
    await tester.pumpAndSettle();

    expect(find.text('Get as much as possible'), findsNothing);
  });

  testWidgets('an unpinned build says there is no most', (tester) async {
    final controller =
        await pumpEditor(tester, twoWays().copyWith(pins: const []));
    controller.select(const NodeSelection('sink_iron'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Get as much as possible'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get as much as possible'));
    await tester.pumpAndSettle();

    // A supply stands for something outside the build, and nothing outside the
    // build is bounded. "As much as you like" is not an answer.
    expect(textContaining('nothing in this build limits it'), findsOneWidget);
  });
}
