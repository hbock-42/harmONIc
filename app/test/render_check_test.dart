@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/design/tokens.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/panels/palette_panel.dart';

import 'support/harness.dart';

/// Renders the app to pictures, so somebody can look at it.
///
/// Everything else in here is an assertion about geometry or arithmetic, and
/// a whole week of work went by on that alone: wires that avoid cards, figures
/// that sit in clear air, a banner that does not shove the canvas about. All
/// of it measured and none of it seen, and the caveat "I have not looked at
/// it" was repeated for two days before anybody tried.
///
/// These write a PNG each. Read them.
///
/// Skipped by default and the results are not committed — a golden is a
/// picture of one machine's font rendering, and text comes out as boxes here
/// because the test font has no glyphs. That is fine for what these are for:
/// layout, colour and geometry. Wording is what the other tests are for.
///
///   fvm flutter test --run-skipped --tags golden --update-goldens \
///     test/render_check_test.dart
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
    await tester.pumpWidget(harness(listening(
      controller,
      (_) => InspectorPanel(
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

  testWidgets('and all of it in the light theme, which nothing has checked',
      (tester) async {
    addTearDown(() => OniTheme.current = OniPalette.dark);
    OniTheme.current = OniPalette.light;

    await useDesktopSurface(tester, size: const Size(1400, 900));
    final base = testPipeline();
    final elec = base.nodeOrThrow('elec');
    final pipeline = base.copyWith(nodes: [
      // Buried, so the banner is there to look at too.
      for (final n in base.nodes)
        if (n.id == 'src_water')
          n.copyWith(x: elec.x, y: elec.y)
        else if (n.id == 'dupes')
          n.copyWith(x: elec.x + 700, y: elec.y - 40)
        else if (n.id == 'h2out')
          n.copyWith(x: elec.x + 330, y: elec.y - 10)
        else
          n,
    ]);
    final controller = testController(pipeline: pipeline);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();

    await expectLater(find.byType(EditorScreen),
        matchesGoldenFile('goldens/light_theme.png'));
  });

  testWidgets('the geothermal boiler, as handed over in a share code',
      (tester) async {
    // A build given to somebody with a description of what they would see.
    // This checks the description was true.
    await useDesktopSurface(tester, size: const Size(1500, 620));
    final pipeline = (PipelineBuilder(testDatabase,
            name: 'Geothermal sour gas boiler')
          ..add('volcano', nodeId: 'volcano', x: 0, y: 260)
          ..add('magma_cooling', nodeId: 'cooling', x: 328, y: 260)
          ..addSink('igneous_rock', nodeId: 'rock_out', x: 656, y: 420)
          ..addSource('petroleum', nodeId: 'oil_in', x: 328, y: 0)
          ..add('sour_gas_boiler', nodeId: 'boiler', x: 656, y: 60)
          ..add('sour_gas_condenser', nodeId: 'condenser', x: 984, y: 60)
          ..addSink('natural_gas', nodeId: 'gas_out', x: 1312, y: 0)
          ..addSink('sulfur', nodeId: 'sulfur_out', x: 1312, y: 160)
          ..addSink('heat', nodeId: 'heat_out', x: 1312, y: 300)
          ..connectItem('volcano', 'cooling', 'magma')
          ..connectItem('cooling', 'rock_out', 'igneous_rock')
          ..connect('cooling', 'heat_out', 'boiler', 'heat_in')
          ..connectItem('oil_in', 'boiler', 'petroleum')
          ..connectItem('boiler', 'condenser', 'sour_gas')
          ..connectItem('condenser', 'gas_out', 'natural_gas')
          ..connectItem('condenser', 'sulfur_out', 'sulfur')
          ..connect('condenser', 'heat_out', 'heat_out', 'in')
          ..pinRate('boiler', 'petroleum', 1000))
        .build();
    final controller = testController(pipeline: pipeline);
    // What was promised: it solves, and it wants 2.16 volcanoes.
    expect(controller.solution.status, SolveStatus.solved);
    expect(controller.solution.nodes['volcano']!.count, closeTo(2.16, 0.01));
    expect(controller.hiddenCards, isEmpty, reason: 'nothing buried');

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
        matchesGoldenFile('goldens/boiler.png'));
  });

  testWidgets('the catalogue, one row per thing rather than per way of keeping it',
      (tester) async {
    await useDesktopSurface(tester, size: const Size(320, 800));
    await tester.pumpWidget(harness(PalettePanel(
      database: testDatabase,
      display: testDisplay(),
      onAdd: (_) {},
      onNewRecipe: () {},
      onEditRecipe: (_) {},
    )));
    await tester.pumpAndSettle();
    await tester.enterText(paletteSearch(), 'hatch');
    await tester.pumpAndSettle();

    // Four kinds of Hatch, each once, and not one wild twin among them.
    for (final name in ['Hatch', 'Sage Hatch', 'Smooth Hatch']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.textContaining('(wild)'), findsNothing);

    await expectLater(find.byType(PalettePanel),
        matchesGoldenFile('goldens/palette.png'));
  });

  testWidgets('mid-drag: the moving card loses its routes and nothing else does',
      (tester) async {
    await useDesktopSurface(tester, size: const Size(1200, 700));
    // Two cards with a card between them, so the wire has to go round.
    final base = testPipeline();
    final elec = base.nodeOrThrow('elec');
    final pipeline = base.copyWith(nodes: [
      for (final n in base.nodes)
        if (n.id == 'dupes')
          n.copyWith(x: elec.x + 700, y: elec.y)
        else if (n.id == 'h2out')
          n.copyWith(x: elec.x + 330, y: elec.y - 10)
        else
          n,
    ]);
    final controller = testController(pipeline: pipeline);
    await tester.pumpWidget(harness(listening(
      controller,
      (_) => GraphCanvas(
        controller: controller,
        rateDisplay: RateDisplay.perSecond,
        onToggleRates: () {},
      ),
    )));
    await tester.pumpAndSettle();
    await expectLater(find.byType(GraphCanvas),
        matchesGoldenFile('goldens/drag_before.png'));

    // Pick up the card in the way and move it, without letting go.
    controller
      ..selectNode('h2out')
      ..beginNodeDrag()
      ..dragSelectionBy(const Offset(40, 190));
    await tester.pump();
    // It really did move, or the two pictures are the same picture.
    expect(controller.pipeline.nodeOrThrow('h2out').y,
        greaterThan(pipeline.nodeOrThrow('h2out').y));
    await expectLater(find.byType(GraphCanvas),
        matchesGoldenFile('goldens/drag_during.png'));

    controller.endNodeDrag();
    await tester.pumpAndSettle();
    await expectLater(find.byType(GraphCanvas),
        matchesGoldenFile('goldens/drag_after.png'));
  });

  testWidgets('two ranches, one groomed and one not, side by side',
      (tester) async {
    await useDesktopSurface(tester, size: const Size(1200, 560));
    final pipeline = (PipelineBuilder(testDatabase, name: 'two ranches')
          ..add('grooming_station', nodeId: 'station', x: 0, y: 0)
          ..add('hatch', nodeId: 'groomed', x: 330, y: 0)
          ..add('hatch', nodeId: 'alone', x: 330, y: 260)
          ..addSource('raw_mineral', nodeId: 'rock', x: 0, y: 260)
          ..addSink('coal', nodeId: 'coal', x: 700, y: 0)
          ..addSink('egg', nodeId: 'eggs', x: 700, y: 200)
          ..connectItem('station', 'groomed', 'grooming')
          ..connectItem('rock', 'groomed', 'raw_mineral')
          ..connectItem('rock', 'alone', 'raw_mineral')
          ..connectItem('groomed', 'coal', 'coal')
          ..connectItem('groomed', 'eggs', 'egg')
          ..pinCount('groomed', 8)
          ..pinCount('alone', 8))
        .build();
    // The second ranch keeps itself.
    final controller = testController(
        pipeline: pipeline.copyWith(nodes: [
      for (final n in pipeline.nodes)
        if (n.id == 'alone')
          n.copyWith(portsSwitchedOff: {'grooming'})
        else
          n,
    ]));

    final key = GlobalKey<GraphCanvasState>();
    await tester.pumpWidget(harness(listening(
      controller,
      (_) => GraphCanvas(
        key: key,
        controller: controller,
        rateDisplay: RateDisplay.perSecond,
        onToggleRates: () {},
      ),
    )));
    await tester.pumpAndSettle();
    key.currentState!.fitToContent();
    await tester.pumpAndSettle();

    await expectLater(find.byType(GraphCanvas),
        matchesGoldenFile('goldens/two_ranches.png'));
  });

  testWidgets('the first thing anybody sees: an empty app', (tester) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));
    final controller = testController(pipeline: Pipeline(
      id: 'untitled',
      name: 'Untitled pipeline',
      dataVersion: testDatabase.dataVersion,
    ));
    final workspace = await testWorkspace(controller);
    await tester.pumpWidget(harness(listening(
      controller,
      (_) => EditorScreen(
        controller: controller,
        library: testLibrary(),
        workspace: workspace,
        displaySettings: testDisplay(),
      ),
    )));
    await tester.pumpAndSettle();

    await expectLater(find.byType(EditorScreen),
        matchesGoldenFile('goldens/empty.png'));
  });
}
