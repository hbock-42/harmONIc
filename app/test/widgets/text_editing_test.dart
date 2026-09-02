import 'package:flutter/gestures.dart';
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

  group('selecting text with the mouse', () {
    /// A field on its own, at a known place, wide enough to click about in.
    Future<TextEditingController> pumpField(WidgetTester tester,
        {String text = 'hello world here'}) async {
      final controller = TextEditingController(text: text);
      addTearDown(controller.dispose);
      await tester.pumpWidget(harness(Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 400, child: OniField(controller: controller)),
      )));
      return controller;
    }

    Offset startOfText(WidgetTester tester) =>
        tester.getTopLeft(find.byType(EditableText)) + const Offset(6, 8);

    testWidgets('double-clicking takes the word under the pointer',
        (tester) async {
      // EditableText draws a cursor and a selection and answers the keyboard,
      // and listens to the mouse not at all. Material's TextField wraps it in
      // a TextSelectionGestureDetector for that; this field was built straight
      // on EditableText to keep Material out, and so had none. A click placed
      // the caret and every other way of selecting did nothing.
      final controller = await pumpField(tester);
      final at = startOfText(tester);

      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(controller.selection.textInside(controller.text), 'hello');
    });

    testWidgets('and dragging across takes what it crossed', (tester) async {
      final controller = await pumpField(tester);
      final at = startOfText(tester);

      final drag = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
      await drag.moveTo(at + const Offset(40, 0));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      // That it is a range at all is the whole claim. Which characters it
      // lands on depends on where 40 pixels falls in whatever font the test
      // runs with, and asserting a particular word here was a test about font
      // metrics wearing a selection test's name.
      expect(controller.selection.isCollapsed, isFalse,
          reason: 'a drag across text selects a range of it');
      expect(controller.selection.textInside(controller.text), isNotEmpty);
    });

    testWidgets('a single click still just places the caret', (tester) async {
      // The thing that did work, kept working.
      final controller = await pumpField(tester);
      await tester.tapAt(startOfText(tester), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, isTrue);
    });

    testWidgets('and select-all takes the lot', (tester) async {
      // Reported alongside the others and not actually broken, so this is a
      // guard rather than a fix.
      //
      // Held with Ctrl here, because a widget test runs as Android unless it
      // is told otherwise and select-all is Ctrl+A there. Pressing ⌘A in a
      // test proves nothing without overriding the platform, and overriding it
      // is global state the framework complains about afterwards -- which is
      // why EditorScreen takes an `apple` flag instead. Checked by hand as ⌘A
      // on a Mac, where it selects the lot as well.
      final controller = await pumpField(tester);
      await tester.tapAt(startOfText(tester), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(controller.selection.textInside(controller.text),
          'hello world here');
    });
  });
}
