@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';

import 'support/harness.dart';

/// Renders the canvas so somebody can look at it.
void main() {
  testWidgets('the canvas, with wires that have to go round things',
      (tester) async {
    await useDesktopSurface(tester, size: const Size(1200, 800));
    final base = testPipeline();
    // A card parked squarely in the way of the oxygen line, and the sink
    // pushed far right so the wire is long.
    final elec = base.nodeOrThrow('elec');
    final pipeline = base.copyWith(nodes: [
      for (final n in base.nodes)
        if (n.id == 'dupes')
          n.copyWith(x: elec.x + 700, y: elec.y - 40)
        else if (n.id == 'h2out')
          n.copyWith(x: elec.x + 330, y: elec.y - 10)
        else
          n,
    ]);
    final controller = testController(pipeline: pipeline);
    await tester.pumpWidget(harness(GraphCanvas(
      controller: controller,
      rateDisplay: RateDisplay.perSecond,
      onToggleRates: () {},
    )));
    await tester.pumpAndSettle();

    await expectLater(find.byType(GraphCanvas),
        matchesGoldenFile('goldens/canvas.png'));
  });

  testWidgets('the editor, with a buried card and a banner over the canvas',
      (tester) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));
    final base = testPipeline();
    final elec = base.nodeOrThrow('elec');
    // One card dropped on another, which is what makes the banner appear.
    final pipeline = base.copyWith(nodes: [
      for (final n in base.nodes)
        if (n.id == 'src_water') n.copyWith(x: elec.x, y: elec.y) else n,
    ]);
    final controller = testController(pipeline: pipeline);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();
    expect(controller.hiddenCards, isNotEmpty);

    await expectLater(find.byType(EditorScreen),
        matchesGoldenFile('goldens/editor_banner.png'));
  });

  testWidgets('a real build somebody sent in, fitted to the window',
      (tester) async {
    final file = File('/tmp/wk/big1b.txt');
    if (!file.existsSync()) return;
    await useDesktopSurface(tester, size: const Size(1600, 1000));
    final controller = testController(
        pipeline: PipelineShareCode.decode(file.readAsStringSync().trim()));
    final key = GlobalKey<GraphCanvasState>();
    await tester.pumpWidget(harness(GraphCanvas(
      key: key,
      controller: controller,
      rateDisplay: RateDisplay.perSecond,
      onToggleRates: () {},
    )));
    await tester.pumpAndSettle();
    key.currentState!.fitToContent();
    await tester.pumpAndSettle();

    await expectLater(find.byType(GraphCanvas),
        matchesGoldenFile('goldens/real_build.png'));
  });

  testWidgets('and close up, where the wires actually bend', (tester) async {
    final file = File('/tmp/wk/big1b.txt');
    if (!file.existsSync()) return;
    await useDesktopSurface(tester, size: const Size(1400, 900));
    final pipeline = PipelineShareCode.decode(file.readAsStringSync().trim());
    final controller = testController(pipeline: pipeline);
    final key = GlobalKey<GraphCanvasState>();
    await tester.pumpWidget(harness(GraphCanvas(
      key: key,
      controller: controller,
      rateDisplay: RateDisplay.perSecond,
      onToggleRates: () {},
    )));
    await tester.pumpAndSettle();

    // The busiest node there is, which is where the bends are.
    final counts = <String, int>{};
    for (final e in pipeline.edges) {
      counts[e.fromNodeId] = (counts[e.fromNodeId] ?? 0) + 1;
      counts[e.toNodeId] = (counts[e.toNodeId] ?? 0) + 1;
    }
    final busiest = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final node = pipeline.nodeOrThrow(busiest.key);
    key.currentState!.centreOn(Offset(node.x + 300, node.y));
    await tester.pumpAndSettle();

    await expectLater(find.byType(GraphCanvas),
        matchesGoldenFile('goldens/close_up.png'));
  });

  testWidgets('the marks a card wears: OVER, NEEDS, SPARE', (tester) async {
    await useDesktopSurface(tester, size: const Size(1100, 420));
    // Forty Duplicants breathing what one Electrolyzer makes: the reported
    // shape, where the maker is held to a size by what feeds it.
    final pipeline = (PipelineBuilder(testDatabase, name: 'over-drawn')
          ..addSource('water', x: 0, y: 60)
          ..add('electrolyzer', nodeId: 'elec', x: 360, y: 60)
          ..add('duplicant', nodeId: 'dupes', x: 720, y: 60)
          ..connectItem('src_water', 'elec', 'water')
          ..connectItem('elec', 'dupes', 'oxygen')
          ..pinRate('src_water', 'out', 1000)
          ..pinCount('dupes', 40))
        .build();
    final controller = testController(pipeline: pipeline);
    expect(controller.solution.status, SolveStatus.inconsistent);
    final key = GlobalKey<GraphCanvasState>();
    await tester.pumpWidget(harness(GraphCanvas(
      key: key,
      controller: controller,
      rateDisplay: RateDisplay.perSecond,
      onToggleRates: () {},
    )));
    await tester.pumpAndSettle();
    key.currentState!.fitToContent();
    await tester.pumpAndSettle();
    expect(find.text('OVER'), findsOneWidget);

    await expectLater(find.byType(GraphCanvas),
        matchesGoldenFile('goldens/marks.png'));
  });

  testWidgets('the inspector on a Glo Squid, where milking can be declined',
      (tester) async {
    await useDesktopSurface(tester, size: const Size(420, 900));
    final controller = testController(pipeline: testPipeline());
    final id = controller.addNode('glo_squid', Offset.zero);
    controller.selectNode(id);
    await tester.pumpWidget(harness(AnimatedBuilder(
      animation: controller,
      builder: (_, _) => InspectorPanel(
        controller: controller,
        rateDisplay: RateDisplay.perSecond,
        onToggleRates: () {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('supplied:$id.milking')), findsOneWidget);
    // No variants row: the Glo Squid is one of the two critters here with no
    // wild twin, which is a gap in the data rather than in the panel.
    expect(find.text('THIS CREATURE IS ALSO KEPT'), findsNothing);

    await expectLater(find.byType(InspectorPanel),
        matchesGoldenFile('goldens/inspector_squid.png'));
  });
}
