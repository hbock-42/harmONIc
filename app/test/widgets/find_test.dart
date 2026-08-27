import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/find_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Finding a node in a build you cannot see all of.
///
/// A build outgrows its window long before it outgrows its author's patience,
/// and the only way to a node forty screens away was remembering where it had
/// been put.
void main() {
  Pipeline aBuild() => (PipelineBuilder(testDatabase, name: 'Big one')
        ..addSource('water', x: 0, y: 0)
        ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
        ..add('hydrogen_generator', nodeId: 'hgen', x: 680, y: 0)
        ..add('metal_refinery', nodeId: 'refinery', x: 340, y: 4000)
        ..addSource('iron_ore', x: 0, y: 4000)
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'hgen', 'hydrogen')
        ..connectItem('src_iron_ore', 'refinery', 'iron_ore')
        ..pinCount('elec', 4))
      .build();

  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: aBuild());
    await tester.pumpWidget(harness(EditorScreen(
      // Said outright rather than asked of the platform, so the test presses
      // the key this app would bind on a Mac wherever it is run.
      apple: true,
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key,
      {bool meta = false, bool shift = false}) async {
    if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();
  }

  test('it searches what a node is called', () {
    final c = testController(pipeline: aBuild());
    expect(findNodes(c, 'refin').map((m) => m.nodeId), ['refinery']);
    expect(findNodes(c, '').isEmpty, isTrue);
  });

  test('and what it makes or takes, which is how a chain is followed', () {
    // "Where does the hydrogen go" is a question about two nodes, and only one
    // of them has the word in its name.
    final c = testController(pipeline: aBuild());
    final matches = findNodes(c, 'hydrogen');
    expect(matches.map((m) => m.nodeId), containsAll(['hgen', 'elec']));
    // The named one leads; the Electrolyzer is here for its recipe and says so.
    expect(matches.first.nodeId, 'hgen');
    expect(matches.firstWhere((m) => m.nodeId == 'elec').because,
        'makes hydrogen');
  });

  testWidgets('⌘F opens it and typing goes to the first match',
      (tester) async {
    final controller = await pumpEditor(tester);
    expect(find.byType(FindPanel), findsNothing);

    await press(tester, LogicalKeyboardKey.keyF, meta: true);
    expect(find.byType(FindPanel), findsOneWidget);

    await tester.enterText(find.byType(EditableText).last, 'refin');
    await tester.pumpAndSettle();

    // Selecting one node is what brings it into view, so this is the whole of
    // arriving: the Metal Refinery is four thousand pixels down the canvas.
    expect(controller.selectedNodeIds, {'refinery'});
    expect(find.text('1 of 1'), findsOneWidget);
  });

  testWidgets('and Enter walks the matches, wrapping', (tester) async {
    final controller = await pumpEditor(tester);
    await press(tester, LogicalKeyboardKey.keyF, meta: true);
    await tester.enterText(find.byType(EditableText).last, 'hydrogen');
    await tester.pumpAndSettle();

    expect(controller.selectedNodeIds, {'hgen'});
    expect(find.text('1 of 2'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.enter);
    expect(controller.selectedNodeIds, {'elec'});
    expect(find.text('2 of 2'), findsOneWidget);

    // A search that stops at the end makes somebody count.
    await press(tester, LogicalKeyboardKey.enter);
    expect(controller.selectedNodeIds, {'hgen'});

    await press(tester, LogicalKeyboardKey.enter, shift: true);
    expect(controller.selectedNodeIds, {'elec'});
  });

  testWidgets('and escape puts it away', (tester) async {
    await pumpEditor(tester);
    await press(tester, LogicalKeyboardKey.keyF, meta: true);
    expect(find.byType(FindPanel), findsOneWidget);

    await press(tester, LogicalKeyboardKey.escape);
    expect(find.byType(FindPanel), findsNothing);
  });

  testWidgets('and says so when nothing answers', (tester) async {
    await pumpEditor(tester);
    await press(tester, LogicalKeyboardKey.keyF, meta: true);
    await tester.enterText(find.byType(EditableText).last, 'kiln');
    await tester.pumpAndSettle();

    expect(find.text('none'), findsOneWidget);
    expect(textContaining('Nothing in this build answers to that'),
        findsOneWidget);
  });
}
