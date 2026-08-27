import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';

import '../support/harness.dart';

/// A count nothing sets is not a count of zero.
///
/// Reported with a spare-power outlet reading "0.0 W" in a build where the
/// generator's size was nobody's decision: it read as "no spare power", and
/// the honest answer was that the app did not know either.
void main() {
  testWidgets('a node nothing sizes says so instead of saying zero',
      (tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    // A SPOM with the hydrogen vented — which the app used to advise — so
    // nothing ties the generator to anything.
    final base = (PipelineBuilder(testDatabase, name: 'spom')
          ..addSource('water')
          ..add('electrolyzer', nodeId: 'elec')
          ..add('hydrogen_generator', nodeId: 'hgen')
          ..addSink('power')
          ..connectItem('src_water', 'elec', 'water')
          ..connectItem('elec', 'hgen', 'hydrogen')
          ..connect('hgen', 'power_out', 'elec', 'power_in')
          ..connect('hgen', 'power_out', 'sink_power', 'in')
          ..pinRate('src_water', 'out', 1600))
        .build();
    controller.load(base.copyWith(nodes: [
      for (final node in base.nodes)
        if (node.id == 'elec')
          node.copyWith(ventedPorts: {'hydrogen'})
        else
          node,
    ]));

    expect(controller.solution.status, SolveStatus.underdetermined);
    expect(controller.solution.freeNodeIds, isNotEmpty);

    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();

    expect(textContaining('any amount'), findsWidgets);
    // And not a figure somebody would read as an answer.
    expect(find.text('0.0 W'), findsNothing);
  });

  testWidgets('and a build that does have a scale still says the number',
      (tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    // The same build with the hydrogen left alone solves: the generator burns
    // all of it and the outlet catches what the Electrolyzer does not use.
    controller.load((PipelineBuilder(testDatabase, name: 'spom')
          ..addSource('water')
          ..add('electrolyzer', nodeId: 'elec')
          ..add('hydrogen_generator', nodeId: 'hgen')
          ..addSink('power')
          ..connectItem('src_water', 'elec', 'water')
          ..connectItem('elec', 'hgen', 'hydrogen')
          ..connect('hgen', 'power_out', 'elec', 'power_in')
          ..connect('hgen', 'power_out', 'sink_power', 'in')
          ..pinRate('src_water', 'out', 1600))
        .build());

    expect(controller.solution.status, SolveStatus.solved);
    expect(controller.solution.nodes['sink_power']!.count, greaterThan(1000));

    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();

    expect(textContaining('any amount'), findsNothing);
  });
}
