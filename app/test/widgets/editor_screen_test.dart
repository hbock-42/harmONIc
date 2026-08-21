import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/canvas/node_widget.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/main.dart';
import 'package:oni_pipeline/panels/palette_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

void main() {
  /// The palette's own search box — the top bar has a text field too now.
  Finder paletteSearch() => find.descendant(
        of: find.byType(PalettePanel),
        matching: find.byType(OniField),
      );

  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  testWidgets('the app boots with a solved starter pipeline', (tester) async {
    await useDesktopSurface(tester);
    await tester.pumpWidget(OniPipelineApp(
      library: testLibrary(),
      pipelineStore: MemoryJsonStore(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Oxygen for the crew'), findsOneWidget);
    expect(find.byType(GraphCanvas), findsOneWidget);
    expect(textContaining('solved'), findsOneWidget);
  });

  testWidgets('every node in the pipeline is drawn', (tester) async {
    final controller = await pumpEditor(tester);
    expect(find.byType(NodeWidget), findsNWidgets(controller.pipeline.nodes.length));
  });

  testWidgets('tapping a node selects it and fills the inspector',
      (tester) async {
    final controller = await pumpEditor(tester);
    await tester.tap(find.descendant(
      of: find.byType(GraphCanvas),
      matching: find.text('Electrolyzer'),
    ));
    await tester.pump();

    expect(controller.selection, isA<NodeSelection>());
    expect((controller.selection! as NodeSelection).nodeId, 'elec');
    expect(find.text('I HAVE THIS MANY'), findsOneWidget);
  });

  testWidgets('the pin field re-solves the whole graph', (tester) async {
    final controller = await pumpEditor(tester);
    await tester.tap(find.descendant(
      of: find.byType(GraphCanvas),
      matching: find.text('Duplicant'),
    ));
    await tester.pump();

    await tester.enterText(find.byType(OniField).last, '30');
    await tester.pump();

    expect(controller.pinFor('dupes'), isA<BuildingCountPin>());
    expect(controller.solution.nodes['elec']!.count,
        closeTo(3000 / 888, 1e-9));
  });

  testWidgets('clearing the pin says what to do rather than failing',
      (tester) async {
    final controller = await pumpEditor(tester);
    await tester.tap(find.descendant(
      of: find.byType(GraphCanvas),
      matching: find.text('Duplicant'),
    ));
    await tester.pump();
    await tester.tap(find.text('Clear'));
    await tester.pump();

    expect(controller.pipeline.pins, isEmpty);
    expect(controller.solution.status, SolveStatus.underdetermined);
    expect(textContaining('Nothing sets the size'), findsOneWidget);
  });

  testWidgets('the summary bar reports the build totals', (tester) async {
    await pumpEditor(tester);
    expect(find.text('NET POWER'), findsOneWidget);
    expect(find.text('INPUTS NEEDED'), findsOneWidget);
    expect(textContaining('Water'), findsWidgets);
  });

  testWidgets('adding from the palette places a node on the canvas',
      (tester) async {
    final controller = await pumpEditor(tester);
    final before = controller.pipeline.nodes.length;

    await tester.enterText(paletteSearch(), 'Coal Gen');
    await tester.pump();
    await tester.tap(find.descendant(
      of: find.byType(PalettePanel),
      matching: textLabel('Coal Generator'),
    ));
    await tester.pump();

    expect(controller.pipeline.nodes.length, before + 1);
    expect(controller.selection, isA<NodeSelection>());
  });

  testWidgets('the palette search filters the list', (tester) async {
    await pumpEditor(tester);
    await tester.enterText(paletteSearch(), 'Electrolyzer');
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(PalettePanel),
        matching: textLabel('Coal Generator'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(PalettePanel),
        matching: textLabel('Electrolyzer'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('undo and redo walk the edit history', (tester) async {
    final controller = await pumpEditor(tester);
    final before = controller.pipeline.nodes.length;

    controller.addNode('coal_generator', const Offset(100, 100));
    await tester.pump();
    expect(controller.pipeline.nodes.length, before + 1);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(controller.pipeline.nodes.length, before);

    await tester.tap(find.text('Redo'));
    await tester.pump();
    expect(controller.pipeline.nodes.length, before + 1);
  });

  testWidgets('an unverified process is flagged in the inspector',
      (tester) async {
    final controller = await pumpEditor(tester);
    controller.addNode('vulcanizer', const Offset(200, 200));
    await tester.pump();

    expect(textContaining('could not be confirmed'), findsOneWidget);
  });

  testWidgets('a verified process carries no warning', (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    expect(textContaining('could not be confirmed'), findsNothing);
  });

  testWidgets('Tidy rearranges the graph in one undo step', (tester) async {
    final controller = await pumpEditor(tester);
    controller.beginNodeDrag();
    controller.moveNode('elec', const Offset(1600, 1200));
    await tester.pump();

    await tester.tap(find.text('Tidy'));
    await tester.pump();

    final elec = controller.pipeline.nodeOrThrow('elec');
    expect(elec.x, lessThan(1600), reason: 'pulled back into the layout');
    // Left to right: the water supply feeds it, so it must sit further right.
    expect(elec.x, greaterThan(controller.pipeline.nodeOrThrow('src_water').x));

    controller.undo();
    expect(controller.pipeline.nodeOrThrow('elec').x, 1600,
        reason: 'one tidy is one undo');
  });

  testWidgets('Tidy is unavailable with nothing to tidy', (tester) async {
    await useDesktopSurface(tester);
    final controller = PipelineController(testDatabase);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));

    await tester.tap(find.text('Tidy'));
    await tester.pump();
    expect(controller.pipeline.nodes, isEmpty);
    expect(controller.canUndo, isFalse);
  });

  testWidgets('an empty pipeline explains what to do', (tester) async {
    await useDesktopSurface(tester);
    final controller = PipelineController(testDatabase);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.byType(GraphCanvas), findsNothing);
  });
}
