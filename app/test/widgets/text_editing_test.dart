import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/palette_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
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

  Finder searchField() => find.descendant(
        of: find.byType(PalettePanel),
        matching: find.byType(OniField),
      );

  String textOf(WidgetTester tester, Finder field) =>
      tester.widget<EditableText>(find.descendant(
        of: field,
        matching: find.byType(EditableText),
      )).controller.text;

  testWidgets('backspace deletes a character in the search box',
      (tester) async {
    final controller = await pumpEditor(tester);
    final nodesBefore = controller.pipeline.nodes.length;

    await tester.tap(searchField());
    await tester.pump();
    await tester.enterText(searchField(), 'coal');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(textOf(tester, searchField()), 'coa',
        reason: 'the editor-wide delete shortcut must not eat backspace '
            'while a text field has focus');
    expect(controller.pipeline.nodes.length, nodesBefore,
        reason: 'and it certainly must not delete a node');
  });

  testWidgets('backspace still deletes the selected node on the canvas',
      (tester) async {
    final controller = await pumpEditor(tester);
    final nodesBefore = controller.pipeline.nodes.length;

    controller.select(const NodeSelection('elec'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(controller.pipeline.nodes.length, nodesBefore - 1);
    expect(controller.pipeline.node('elec'), isNull);
  });

  testWidgets('backspace deletes a node after using the search box',
      (tester) async {
    // The real-world sequence: search for something, then click a node on the
    // canvas and hit delete. Focus must follow the click, or the guard that
    // protects typing also disables the shortcut for good.
    final controller = await pumpEditor(tester);
    final nodesBefore = controller.pipeline.nodes.length;

    await tester.tap(searchField());
    await tester.pump();
    await tester.enterText(searchField(), 'coal');
    await tester.pump();

    await tester.tap(find.descendant(
      of: find.byType(GraphCanvas),
      matching: find.text('Electrolyzer'),
    ));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(controller.pipeline.nodes.length, nodesBefore - 1);
    expect(textOf(tester, searchField()), 'coal',
        reason: 'and the search text is left alone');
  });

  testWidgets('escape clears the selection', (tester) async {
    final controller = await pumpEditor(tester);
    await tester.tap(find.descendant(
      of: find.byType(GraphCanvas),
      matching: find.text('Electrolyzer'),
    ));
    await tester.pump();
    expect(controller.selection, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.selection, isNull);
  });

  testWidgets('the inspector amount field is editable too', (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('dupes'));
    await tester.pump();

    final amount = find.byType(OniField).last;
    await tester.tap(amount);
    await tester.pump();
    await tester.enterText(amount, '25');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(textOf(tester, amount), '2');
    expect(controller.pipeline.nodes.length, 4, reason: 'nothing was deleted');
  });
}
