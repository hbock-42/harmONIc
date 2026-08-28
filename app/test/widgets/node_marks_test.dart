import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/canvas/node_widget.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// What a node is quietly doing, on the node.
///
/// Asked for: "would it be possible to mark any blocks that have venting
/// toggled on, spare, or needs-supply details shown when you click into them?
/// Realising that was causing imbalance allowed me to diagnose and correct
/// these pipelines." All three were visible only to somebody who opened the
/// node and read down it.
void main() {
  Future<PipelineController> pump(WidgetTester tester, Pipeline pipeline) async {
    await useDesktopSurface(tester);
    final controller = testController()..load(pipeline);
    await tester.pumpWidget(harness(
      GraphCanvas(
        controller: controller,
        rateDisplay: RateDisplay.perSecond,
        onToggleRates: () {},
      ),
    ));
    await tester.pumpAndSettle();
    return controller;
  }

  /// An Electrolyzer wired to Duplicants that want more oxygen than it makes,
  /// and whose hydrogen line carries only part of what it produces.
  testWidgets('a port drawing from outside the build says so', (tester) async {
    // The Electrolyzer's water comes from nowhere named and the Duplicants'
    // calories do too — true, and invisible on a canvas of crossing wires
    // where the question is which port has no wire on it.
    await pump(tester, testPipeline());
    expect(find.text('NEEDS'), findsNWidgets(2));
    // And the carbon dioxide the Duplicants breathe out goes nowhere.
    expect(find.text('SPARE'), findsOneWidget);
  });

  testWidgets('but never on a supply or an output', (tester) async {
    // Drawing from outside the build is the whole of what those are for, so a
    // mark on every one of them says nothing about any of them. A supply
    // wired to nothing at all is the clearest case.
    final base = testPipeline();
    final lonely = (PipelineBuilder(testDatabase, name: 'lonely')
          ..addSource('coal', x: 900, y: 900))
        .build();
    await pump(
      tester,
      base.copyWith(nodes: [...base.nodes, ...lonely.nodes]),
    );

    // The two the build really does draw from outside, and no more: the
    // supply's own output going nowhere is not news.
    expect(find.text('NEEDS'), findsNWidgets(2));
    expect(find.text('SPARE'), findsOneWidget);
  });

  testWidgets('and a vented port is marked, because it is a choice',
      (tester) async {
    final base = testPipeline();
    final vented = base.copyWith(nodes: [
      for (final node in base.nodes)
        if (node.id == 'elec')
          node.copyWith(ventedPorts: const {'hydrogen'})
        else
          node,
    ]);
    await pump(tester, vented);

    expect(find.text('VENT'), findsOneWidget);
  });


  testWidgets('and the marks sit where the SET badge sits', (tester) async {
    // Reported from a screenshot: SET hard against the right edge on one node
    // and VENT stranded mid-header on the next. A Flexible with the default
    // flex of 1 splits the free space with the name beside it.
    final base = testPipeline();
    final vented = base.copyWith(nodes: [
      for (final node in base.nodes)
        if (node.id == 'elec')
          node.copyWith(ventedPorts: const {'hydrogen'})
        else
          node,
    ]);
    await pump(tester, vented);

    // The marks end where SET ends: hard against the node's right edge,
    // whatever the name beside them does.
    Offset edgeOf(Finder badge) {
      final node = find.ancestor(of: badge, matching: find.byType(NodeWidget));
      return tester.getTopRight(node) - tester.getTopRight(badge);
    }

    // On the Electrolyzer the last mark is NEEDS; on the Duplicants it is SET.
    expect(edgeOf(find.text('NEEDS').first).dx,
        closeTo(edgeOf(find.text('SET')).dx, 1));
  });
}
