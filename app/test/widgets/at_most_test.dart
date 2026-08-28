import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Saying what you have, as a ceiling rather than an amount.
///
/// "I have this much" on a supply meant *exactly* that much flows, so a supply
/// with more than the build needed contradicted it. Both readings are real;
/// the app had one.
void main() {
  Pipeline gasAndRock() => (PipelineBuilder(testDatabase, name: 'what I have')
        ..add('natural_gas_generator', nodeId: 'gen')
        ..addSource('natural_gas')
        ..addSink('power')
        ..add('rock_crusher_sand', nodeId: 'crusher')
        ..addSource('raw_mineral')
        ..addSink('sand')
        ..connectItem('src_natural_gas', 'gen', 'natural_gas')
        ..connect('gen', 'power_out', 'sink_power', 'in')
        ..connect('gen', 'power_out', 'crusher', 'power_in')
        ..connectItem('src_raw_mineral', 'crusher', 'raw_mineral')
        ..connectItem('crusher', 'sink_sand', 'sand'))
      .build();

  test('a ceiling belongs to the supply, not to each of its lines', () {
    // It used to be written onto every line, which made it a ceiling *per
    // line*: a supply feeding two things gave twice what was allowed, and a
    // build capped at ten kilograms of ore a second answered fifteen
    // kilograms of iron.
    final controller = testController()..load(gasAndRock());

    controller.setSupplyCeiling('src_natural_gas', 180);

    expect(controller.supplyCeiling('src_natural_gas'), 180);
    expect(controller.pipeline.nodeOrThrow('src_natural_gas').capPerSecond,
        180);
    expect(
      controller.pipeline.edges
          .where((e) => e.fromNodeId == 'src_natural_gas')
          .every((e) => e.capPerSecond == null),
      isTrue,
      reason: 'the lines carry valves of their own and this is not one',
    );
  });

  test('and a build saved with the old one still reads', () {
    // Builds are out there carrying the ceiling as the same figure on every
    // line, which is what it used to mean.
    final was = gasAndRock();
    final controller = testController()
      ..load(was.copyWith(edges: [
        for (final edge in was.edges)
          if (edge.fromNodeId == 'src_natural_gas')
            edge.copyWith(capPerSecond: 180)
          else
            edge,
      ]));

    expect(controller.supplyCeiling('src_natural_gas'), 180);
  });

  test('and clearing it takes the valve off again', () {
    final controller = testController()..load(gasAndRock());
    controller
      ..setSupplyCeiling('src_natural_gas', 180)
      ..setSupplyCeiling('src_natural_gas', null);

    expect(controller.supplyCeiling('src_natural_gas'), isNull);
    expect(
      controller.pipeline.edges
          .firstWhere((e) => e.fromNodeId == 'src_natural_gas')
          .capPerSecond,
      isNull,
    );
  });

  test('a ceiling does not size the build, and an amount does', () {
    // The difference, in one test. A ceiling says what you have; it takes an
    // amount, or the optimiser, to say how big the build is.
    final ceiling = testController()..load(gasAndRock());
    ceiling.setSupplyCeiling('src_natural_gas', 180);
    expect(ceiling.solution.status, SolveStatus.underdetermined);

    final amount = testController()..load(gasAndRock());
    amount.pin(const PortRatePin(
        nodeId: 'src_natural_gas', portId: 'out', ratePerSecond: 180));
    expect(amount.solution.nodes['gen']!.count, closeTo(2, 1e-6));
  });

  test('and the two together are what "what can I make" is', () {
    // Ceilings on what you have, then ask what comes out for the most it can
    // give: the answer is a build, inside those ceilings.
    final controller = testController()..load(gasAndRock());
    controller
      ..setSupplyCeiling('src_natural_gas', 180)
      ..setSupplyCeiling('src_raw_mineral', 2000);

    final most = controller.optimiseFor('sink_sand');

    expect(most, closeTo(2000, 1e-6));
    expect(controller.solution.status, SolveStatus.solved);
    expect(controller.solution.nodes['src_natural_gas']!.count,
        lessThanOrEqualTo(180 + 1e-6));
  });

  testWidgets('the supply offers both, and says which is which',
      (tester) async {
    await useDesktopSurface(tester);
    final controller = testController()..load(gasAndRock());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    controller.select(const NodeSelection('src_natural_gas'));
    await tester.pumpAndSettle();

    expect(textContaining('I HAVE THIS MUCH'), findsOneWidget);
    expect(textContaining('OR AT MOST THIS MUCH'), findsOneWidget);
    expect(textContaining('the build takes what it needs up to this'),
        findsOneWidget);
  });

  testWidgets('and typing a ceiling puts a valve on the line', (tester) async {
    await useDesktopSurface(tester);
    final controller = testController()..load(gasAndRock());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    controller.select(const NodeSelection('src_natural_gas'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.ancestor(
        of: find.text('ceiling'),
        matching: find.byType(OniField),
      ),
      '180',
    );
    await tester.pumpAndSettle();

    expect(controller.supplyCeiling('src_natural_gas'), 180);
  });
}
