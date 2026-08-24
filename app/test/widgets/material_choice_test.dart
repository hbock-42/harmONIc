import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final pipeline = (PipelineBuilder(testDatabase, name: 'Smelting')
          ..addSource('iron_ore', x: 0, y: 0)
          ..add('metal_refinery', nodeId: 'refinery', x: 340, y: 0)
          ..connectItem('src_iron_ore', 'refinery', 'iron_ore')
          ..pinCount('refinery', 1))
        .build();
    final controller = testController(pipeline: pipeline);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    controller.select(const NodeSelection('refinery'));
    await tester.pump();
    return controller;
  }

  testWidgets('a refinery offers the ores it could be smelting',
      (tester) async {
    await pumpEditor(tester);

    // Below the variants of the building itself, which arrived when a node
    // learned it could be swapped for another recipe of the same machine. The
    // panel builds lazily, so scroll to it as a person would.
    await tester.drag(find.byType(InspectorPanel), const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(find.text('METAL ORE USED'), findsOneWidget);
    expect(find.text('Any'), findsOneWidget);
    expect(find.text('Copper Ore'), findsWidgets);
    expect(textContaining('Pick an ore if something downstream needs'),
        findsOneWidget);
  });

  testWidgets('picking one says what comes out of it', (tester) async {
    final controller = await pumpEditor(tester);

    // The ore buttons sit near the bottom of a panel that has grown, so reach
    // them the way a person would.
    await tester.drag(find.byType(InspectorPanel), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Copper Ore').first);
    await tester.pump();
    await tester.tap(find.text('Copper Ore').first);
    await tester.pumpAndSettle();

    expect(controller.pipeline.nodeOrThrow('refinery').materials,
        {'metal_ore': 'copper_ore'});
    // The note sits under the buttons, which the choice has just shifted.
    await tester.drag(find.byType(InspectorPanel), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(textContaining('Makes Copper'), findsOneWidget);
  });

  testWidgets('the node itself is renamed by the choice', (tester) async {
    final controller = await pumpEditor(tester);
    // Generic to begin with, so the ports read as the class.
    expect(find.text('Refined Metal'), findsWidgets);

    controller.setMaterial('refinery', 'metal_ore', 'gold_amalgam');
    await tester.pump();

    expect(find.text('Gold'), findsWidgets);
    expect(find.text('Refined Metal'), findsNothing);
  });

  testWidgets('a choice that contradicts the wiring is reported', (tester) async {
    final controller = await pumpEditor(tester);
    // Fed iron ore, told to smelt copper: the wire is now wrong, and saying so
    // is the whole reason the choice exists.
    controller.setMaterial('refinery', 'metal_ore', 'copper_ore');
    await tester.pump();

    expect(controller.solution.status, SolveStatus.invalid);
    expect(
        controller.solution.issues
            .map((i) => i.message)
            .join()
            .toLowerCase(),
        contains('carries iron_ore'));
  });

  testWidgets('the one ore the recipe cannot describe is not offered',
      (tester) async {
    await pumpEditor(tester);
    await tester.drag(find.byType(InspectorPanel), const Offset(0, -240));
    await tester.pumpAndSettle();

    // Galena is 87 % lead and 13 % sulfur, so "kilogram for kilogram" does not
    // describe it and it has recipes of its own. Offering it *as an ore* here
    // would be the app quietly agreeing to figures it does not hold — while
    // offering it as another recipe of the same building, which the row above
    // now does, is exactly right.
    expect(
      find.descendant(
        of: find.byType(MaterialChoiceRow),
        matching: find.text('Galena'),
      ),
      findsNothing,
    );
    expect(find.text('Cinnabar Ore'), findsWidgets);
  });
}
