import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  /// One Electrolyzer's oxygen split between a crew and an Oxylite Refinery,
  /// which is the case the app used to decide for you.
  Pipeline split() => (PipelineBuilder(testDatabase, name: 'Split')
        ..addSource('water', x: 0, y: 0)
        ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
        ..add('duplicant', nodeId: 'dupes', x: 680, y: 0)
        ..add('oxylite_refinery', nodeId: 'refinery', x: 680, y: 300)
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'dupes', 'oxygen', mode: EdgeMode.push)
        ..connectItem('elec', 'refinery', 'oxygen', mode: EdgeMode.push)
        ..pinCount('elec', 2))
      .build();

  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: split());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  String firstOxygenEdge(PipelineController c) => c.pipeline.edges
      .firstWhere((e) => e.toNodeId == 'dupes')
      .id;

  testWidgets('a push line says what share it takes, and offers to change it',
      (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(EdgeSelection(firstOxygenEdge(controller)));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('TAKES'), 120,
        scrollable: find
            .descendant(
                of: find.byType(InspectorPanel),
                matching: find.byType(Scrollable))
            .first);
    await tester.pump();

    expect(find.text('TAKES'), findsOneWidget);
    expect(find.text('An even split'), findsOneWidget);
    // It says how many it is sharing with, rather than "between them" —
    // which was said whether there was one other line or six, and was said
    // about producer-driven lines only.
    expect(textContaining('equally with 1 other line'), findsOneWidget);
  });

  testWidgets('setting one moves the oxygen, and the other line takes the rest',
      (tester) async {
    final controller = await pumpEditor(tester);
    final toDupes = firstOxygenEdge(controller);

    // Half each by default: 888 g/s from two Electrolyzers is 1 776, so 888
    // to each side.
    expect(controller.solution.edgeFlows[toDupes], closeTo(888, 1e-6));

    controller.setEdgeShare(toDupes, 0.75);
    await tester.pump();

    expect(controller.solution.edgeFlows[toDupes], closeTo(1776 * 0.75, 1e-6));
    // And the unshared line picks up what is left rather than keeping its half.
    final toRefinery =
        controller.pipeline.edges.firstWhere((e) => e.toNodeId == 'refinery');
    expect(controller.solution.edgeFlows[toRefinery.id],
        closeTo(1776 * 0.25, 1e-6));
  });

  testWidgets('a pull line is not offered one, having nothing to decide',
      (tester) async {
    final controller = await pumpEditor(tester);
    final water =
        controller.pipeline.edges.firstWhere((e) => e.toNodeId == 'elec');
    controller.select(EdgeSelection(water.id));
    await tester.pump();

    // A pull line carries whatever its consumer needs; there is no share to
    // set, and offering one would be offering a decision that does nothing.
    expect(find.text('TAKES'), findsNothing);
  });
}
