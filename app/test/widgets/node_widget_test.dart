import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/geometry.dart';
import 'package:oni_pipeline/canvas/node_widget.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  Future<PipelineController> pumpNode(WidgetTester tester, String nodeId) async {
    final controller = testController();
    final node = controller.pipeline.nodeOrThrow(nodeId);
    await tester.pumpWidget(harness(
      Align(
        alignment: Alignment.topLeft,
        child: NodeWidget(
          node: node,
          spec: controller.specOf(node),
          controller: controller,
          selected: false,
          rateDisplay: RateDisplay.perSecond,
          onPortTap: (_, _) {},
          onPortDragStart: (_, _) {},
          onPortDragUpdate: (_) {},
          onPortDragEnd: (_) {},
          highlightPort: (_) => false,
        ),
      ),
    ));
    return controller;
  }

  testWidgets('a building shows its name, count and how many to build',
      (tester) async {
    await pumpNode(tester, 'elec');

    expect(find.text('Electrolyzer'), findsOneWidget);
    // 10 dupes pull 1000 g/s of oxygen → 1.13 Electrolyzers → build 2.
    expect(textContaining('1.13 ×'), findsOneWidget);
    expect(textContaining('build 2'), findsOneWidget);
  });

  testWidgets('every port of the spec gets a labelled dot', (tester) async {
    final controller = await pumpNode(tester, 'elec');
    final spec = controller.database.processOrThrow('electrolyzer');

    for (final port in spec.ports) {
      final item = controller.database.item(port.itemId);
      expect(find.text(item!.name), findsWidgets,
          reason: 'port ${port.id} should be labelled');
    }
  });

  testWidgets('a boundary node reads as a rate, not a building count',
      (tester) async {
    await pumpNode(tester, 'src_water');

    // 1.13 Electrolyzers drink 1126 g/s.
    expect(textContaining('kg/s'), findsWidgets);
    expect(textContaining('build'), findsNothing);
  });

  testWidgets('the widget matches the size the painter assumes',
      (tester) async {
    final controller = await pumpNode(tester, 'elec');
    final spec = controller.database.processOrThrow('electrolyzer');
    final rendered = tester.getSize(find.byType(NodeWidget));

    expect(rendered, NodeLayout.sizeOf(spec),
        reason: 'if these drift, every wire lands off its dot');
  });

  testWidgets('port dots sit where the geometry says they do', (tester) async {
    final controller = await pumpNode(tester, 'elec');
    final spec = controller.database.processOrThrow('electrolyzer');
    final origin = tester.getTopLeft(find.byType(NodeWidget));

    // The water input is the first input row. Its dot must sit exactly where
    // the edge painter will draw the wire's end, in both axes.
    final expected = origin + NodeLayout.portOffset(spec, 'water');
    final dot = tester.getCenter(find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == 18 && w.height == NodeLayout.portRowHeight,
    ).first);
    expect((dot.dx - expected.dx).abs(), lessThan(0.5));
    expect((dot.dy - expected.dy).abs(), lessThan(0.5));

    final waterLabel = tester.getCenter(find.text('Water'));
    expect((waterLabel.dy - expected.dy).abs(), lessThan(2),
        reason: 'the dot and its label share a row');
  });
}
