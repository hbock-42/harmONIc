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

  testWidgets('the same ranch left wild asks for no Duplicant time',
      (tester) async {
    final wild = (PipelineBuilder(testDatabase, name: 'Wild hatches')
          ..add('hatch_wild', nodeId: 'hatches', x: 0, y: 100)
          ..add('coal_generator', nodeId: 'gen', x: 340, y: 100)
          ..connectItem('hatches', 'gen', 'coal')
          ..pinCount('hatches', 12))
        .build();
    final controller = await pumpEditor(tester, pipeline: wild);

    expect(controller.solution.dupeLabourSecondsPerCycle, 0);
    expect(find.text('DUPE TIME'), findsNothing);
  });

  testWidgets('grazing a wild patch takes four times the plants',
      (tester) async {
    Pipeline grazing(String plant) =>
        (PipelineBuilder(testDatabase, name: 'Squid pen')
              ..add(plant, nodeId: 'plants', x: 0, y: 100)
              ..add('glo_squid', nodeId: 'squid', x: 340, y: 100)
              ..connectItem('plants', 'squid', 'tublia_growth')
              ..pinCount('squid', 4))
            .build();

    final farmed = await pumpEditor(tester, pipeline: grazing('tublia_grazed'));
    final farmedCount = farmed.solution.nodes['plants']!.count;

    final wild =
        await pumpEditor(tester, pipeline: grazing('tublia_grazed_wild'));

    expect(wild.solution.nodes['plants']!.count,
        closeTo(farmedCount * 4, 1e-6));
    // Nobody is watering the wild patch, so no brine is being asked for.
    expect(wild.solution.itemBalances.containsKey('polluted_brine'), isFalse);
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

  group('a ranch nobody grooms', () {
    /// The same twelve hatches with the grooming declined.
    Pipeline ungroomed() {
      final base = ranch();
      return base.copyWith(nodes: [
        for (final node in base.nodes)
          if (node.id == 'hatches')
            node.copyWith(portsSwitchedOff: const {'grooming'})
          else
            node,
      ]);
    }

    double coalFrom(PipelineController c) => c.solution.portBalances
        .firstWhere(
            (b) => b.ref.nodeId == 'hatches' && b.ref.portId == 'coal')
        .rate;

    double rockInto(PipelineController c) => c.solution.portBalances
        .firstWhere((b) =>
            b.ref.nodeId == 'hatches' && b.ref.portId == 'raw_mineral')
        .rate;

    testWidgets('eats a fifth and makes a fifth, all the way to the screen',
        (tester) async {
      // The engine knows this; the question here is whether the number a
      // person reads off the card moved with it. A glum critter has a -80 %
      // metabolism offset, and this app used to say metabolism did not care.
      final groomed = await pumpEditor(tester);
      final wasCoal = coalFrom(groomed);
      final wasRock = rockInto(groomed);
      expect(wasCoal, greaterThan(0));

      final not = await pumpEditor(tester, pipeline: ungroomed());
      expect(coalFrom(not), closeTo(wasCoal * 0.2, 1e-6));
      expect(rockInto(not), closeTo(wasRock * 0.2, 1e-6));
    });

    testWidgets('and lays a tenth, which is a different column', (tester) async {
      // The two do not move together, which is the whole reason they are two
      // columns: a fifth of the coal and a tenth of the eggs.
      double eggs(PipelineController c) => c.solution.portBalances
          .firstWhere(
              (b) => b.ref.nodeId == 'hatches' && b.ref.portId == 'egg')
          .rate;

      final groomed = await pumpEditor(tester);
      final wasEggs = eggs(groomed);
      final not = await pumpEditor(tester, pipeline: ungroomed());
      expect(eggs(not), closeTo(wasEggs * 0.1, 1e-6));
    });

    testWidgets('and the generator it feeds shrinks with it', (tester) async {
      // What a person actually notices: the ranch was drawn to run a coal
      // generator, and a fifth of the coal runs a fifth of the generator.
      final groomed = await pumpEditor(tester);
      final wasGen = groomed.solution.nodes['gen']!.count;

      final not = await pumpEditor(tester, pipeline: ungroomed());
      expect(not.solution.nodes['gen']!.count, closeTo(wasGen * 0.2, 1e-6));
      expect(wasGen, greaterThan(0));
    });

    testWidgets('and it says on the card that something is switched off',
        (tester) async {
      await pumpEditor(tester, pipeline: ungroomed());
      expect(find.text('OFF'), findsOneWidget,
          reason: 'a build reading a fifth of what it did has to say why');
    });
  });
}
