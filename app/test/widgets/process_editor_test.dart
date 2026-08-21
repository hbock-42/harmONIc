import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/palette_panel.dart';
import 'package:oni_pipeline/panels/process_editor.dart';
import 'package:oni_pipeline/state/library_controller.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

void main() {
  late LibraryController library;
  late PipelineController controller;
  late MemoryJsonStore store;

  Future<void> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    store = MemoryJsonStore();
    library = testLibrary(store);
    controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: library,
      workspace: await testWorkspace(controller),
    )));
  }

  Future<void> openNewRecipe(WidgetTester tester) async {
    await tester.tap(find.text('+ Recipe'));
    await tester.pump();
  }

  Finder editorField(int index) => find.descendant(
        of: find.byType(ProcessEditor),
        matching: find.byType(OniField),
      ).at(index);

  testWidgets('the palette opens a blank recipe form', (tester) async {
    await pumpEditor(tester);
    await openNewRecipe(tester);

    expect(find.byType(ProcessEditor), findsOneWidget);
    expect(find.text('Add a recipe'), findsOneWidget);
  });

  testWidgets('editing an existing process says it will be overridden',
      (tester) async {
    await pumpEditor(tester);
    // Narrow the list first — the catalogue is far taller than the panel.
    await tester.enterText(
      find.descendant(
        of: find.byType(PalettePanel),
        matching: find.byType(OniField),
      ),
      'Electrolyzer',
    );
    await tester.pump();

    // Hovering reveals the edit affordance on a palette row.
    final gesture =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.descendant(
      of: find.byType(PalettePanel),
      matching: textLabel('Electrolyzer'),
    )));
    await tester.pump();

    await tester.tap(find.descendant(
      of: find.byType(PalettePanel),
      matching: find.text('edit'),
    ));
    await tester.pump();

    expect(find.text('Correct a recipe'), findsOneWidget);
    expect(textContaining('replace the ones that ship'), findsOneWidget);
  });

  testWidgets('a saved recipe reaches the catalogue and the canvas',
      (tester) async {
    await pumpEditor(tester);
    await openNewRecipe(tester);

    await tester.enterText(editorField(0), 'Beakon');
    await tester.pump();

    await tester.tap(find.text('+ Consumes'));
    await tester.pump();
    // Pick the item for the new line.
    await tester.tap(find.text('Choose an item…'));
    await tester.pump();
    await tester.enterText(find.byKey(itemPickerSearchKey), 'Phosphorite');
    await tester.pump();
    await tester.tap(find.descendant(
      of: find.byType(ProcessEditor),
      matching: textLabel('Phosphorite'),
    ));
    await tester.pump();

    await tester.enterText(editorField(1), '50');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(ProcessEditor), findsNothing);
    final saved = library.database.process(library.customProcesses.first.id);
    expect(saved, isNotNull);
    expect(saved!.name, 'Beakon');
    expect(saved.inputs.single.itemId, 'phosphorite');
    expect(saved.inputs.single.ratePerSecond, 50);
    expect(saved.tags, contains('unverified'),
        reason: 'a hand-entered recipe is never presented as confirmed');
  });

  testWidgets('a saved recipe is written to storage', (tester) async {
    await pumpEditor(tester);
    await openNewRecipe(tester);
    await tester.enterText(editorField(0), 'Beakon');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.data, isNotNull);
    final processes = store.data!['processes'] as List<dynamic>;
    expect(processes, hasLength(1));
    expect((processes.single as Map<String, dynamic>)['name'], 'Beakon');
  });

  testWidgets('the form refuses a nameless recipe', (tester) async {
    await pumpEditor(tester);
    await openNewRecipe(tester);
    await tester.enterText(editorField(0), '');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Give it a name.'), findsOneWidget);
    expect(find.byType(ProcessEditor), findsOneWidget);
  });

  testWidgets('an overridden recipe changes the numbers on the canvas',
      (tester) async {
    await pumpEditor(tester);
    final before = controller.solution.nodes['elec']!.count;

    await library.save(ProcessSpec(
      id: 'electrolyzer',
      name: 'Electrolyzer',
      kind: ProcessKind.building,
      tags: const {'custom', 'unverified'},
      description: 'UNVERIFIED: halved.',
      ports: const [
        Port(
          id: 'water',
          itemId: 'water',
          direction: PortDirection.input,
          ratePerSecond: 1000,
        ),
        Port(
          id: 'oxygen',
          itemId: 'oxygen',
          direction: PortDirection.output,
          ratePerSecond: 444,
        ),
        Port(
          id: 'hydrogen',
          itemId: 'hydrogen',
          direction: PortDirection.output,
          ratePerSecond: 112,
        ),
      ],
    ));
    await tester.pump();

    expect(controller.solution.nodes['elec']!.count,
        closeTo(before * 2, 1e-6),
        reason: 'the canvas follows the corrected recipe without a restart');
  });

  testWidgets('cancelling saves nothing', (tester) async {
    await pumpEditor(tester);
    await openNewRecipe(tester);
    await tester.enterText(editorField(0), 'Discard me');
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(find.byType(ProcessEditor), findsNothing);
    expect(library.customProcesses, isEmpty);
    expect(store.data, isNull);
  });
}
