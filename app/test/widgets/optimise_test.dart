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

  testWidgets('a supply node asks the same question from the other end',
      (tester) async {
    // You have said what you want: 5 kg/s of iron. The question is now what it
    // costs you, and the answer is a third less ore.
    final pipeline = twoWays().copyWith(pins: [
      const PortRatePin(
          nodeId: 'sink_iron', portId: 'in', ratePerSecond: 5000),
    ]);
    final controller = await pumpEditor(tester, pipeline);
    expect(controller.solution.nodes['src_iron_ore']!.count,
        closeTo(7500, 1e-6));

    controller.select(const NodeSelection('src_iron_ore'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use as little as possible'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use as little as possible'));
    await tester.pumpAndSettle();

    expect(controller.solution.nodes['src_iron_ore']!.count,
        closeTo(5000, 1e-6));
    expect(controller.solution.nodes['sink_iron']!.count, closeTo(5000, 1e-6),
        reason: 'and you still get what you asked for');
    expect(textContaining('Divided to need only'), findsOneWidget);
  });

  testWidgets('and an output node is not asked to use less of itself',
      (tester) async {
    // The two ends ask different questions, and each node asks only its own.
    final controller = await pumpEditor(tester, twoWays());
    controller.select(const NodeSelection('sink_iron'));
    await tester.pumpAndSettle();

    expect(find.text('Use as little as possible'), findsNothing);
    expect(find.text('Get as much as possible'), findsOneWidget);
  });

  testWidgets('a total in the bar can be asked to be smaller', (tester) async {
    final pipeline = twoWays().copyWith(pins: [
      const PortRatePin(
          nodeId: 'sink_iron', portId: 'in', ratePerSecond: 5000),
    ]);
    final controller = await pumpEditor(tester, pipeline);

    // Three figures offer it: net power, heat and floor.
    expect(find.text('LEAST'), findsNWidgets(3));
    final before = controller.focusedSolution.totalFootprintTiles;

    // The floor one is the last of the three, in the order the bar lists them.
    await tester.tap(find.text('LEAST').at(2));
    await tester.pumpAndSettle();

    expect(controller.focusedSolution.totalFootprintTiles, lessThan(before));
    // And it still delivers what was asked of it.
    expect(controller.solution.nodes['sink_iron']!.count, closeTo(5000, 1e-6));
  });

  testWidgets('and with nothing divided, no figure offers it', (tester) async {
    await pumpEditor(tester, oneWay());
    expect(find.text('LEAST'), findsNothing);
  });
}
