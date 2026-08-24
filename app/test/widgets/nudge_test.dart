import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/canvas/geometry.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
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

  Offset at(PipelineController c, String id) {
    final node = c.pipeline.nodeOrThrow(id);
    return Offset(node.x, node.y);
  }

  testWidgets('an arrow key moves the selection one grid cell', (tester) async {
    final controller = await pumpEditor(tester);
    controller.selectNode('elec');
    await tester.pump();

    // The first press also lands the node on the grid, since a node dropped by
    // hand is wherever the hand left it. From there each press is one cell.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final aligned = at(controller, 'elec');
    expect(aligned.dx % NodeLayout.gridSize, 0);
    expect(aligned.dy % NodeLayout.gridSize, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(at(controller, 'elec'),
        aligned + const Offset(NodeLayout.gridSize, 0));
  });

  testWidgets('with shift it moves eight of them', (tester) async {
    final controller = await pumpEditor(tester);
    controller.selectNode('elec');
    await tester.pump();
    final before = at(controller, 'elec');

    // Aligned first, so the figure being checked is the step and not the snap.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final aligned = at(controller, 'elec');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(at(controller, 'elec'),
        aligned + const Offset(0, NodeLayout.gridSize * 8));
    expect(before, isNot(aligned));
  });

  testWidgets('a whole selection moves together', (tester) async {
    final controller = await pumpEditor(tester);
    controller.selectNodes({'elec', 'dupes'});
    await tester.pump();
    final elec = at(controller, 'elec');
    final dupes = at(controller, 'dupes');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    // Both moved, and by the same amount bar the snap each needed.
    expect(at(controller, 'elec').dy, lessThan(elec.dy));
    expect(at(controller, 'dupes').dy, lessThan(dupes.dy));
  });

  testWidgets('a run of presses is one undo, not twelve', (tester) async {
    final controller = await pumpEditor(tester);
    controller.selectNode('elec');
    await tester.pump();
    final before = at(controller, 'elec');

    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    expect(at(controller, 'elec').dx, greaterThan(before.dx));

    controller.undo();
    await tester.pump();
    expect(at(controller, 'elec'), before);
  });

  testWidgets('with nothing selected the arrows do nothing', (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(null);
    await tester.pump();
    final before = at(controller, 'elec');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(at(controller, 'elec'), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('and the arrows move the caret, not the node, while typing',
      (tester) async {
    // The bug: a node stays selected while you type into its fields, so an
    // arrow key meant for the caret moved the thing on the canvas instead —
    // and the field never saw the press, because a shortcut that reports a
    // key as handled stops the platform delivering it to the text input.
    final controller = await pumpEditor(tester);
    controller.selectNode('elec');
    await tester.pump();
    final before = at(controller, 'elec');

    await tester.tap(find.byKey(amountFieldKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(amountFieldKey), '12');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(at(controller, 'elec'), before, reason: 'the node did not move');
  });

  testWidgets('and they move it again once the field is let go',
      (tester) async {
    final controller = await pumpEditor(tester);
    controller.selectNode('elec');
    await tester.pump();

    await tester.tap(find.byKey(amountFieldKey));
    await tester.pumpAndSettle();
    final parked = at(controller, 'elec');

    // Clicking the node hands the keyboard back to the canvas, which is what
    // anybody would do next.
    await tester.tap(find.text('Electrolyzer').first);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(at(controller, 'elec'), isNot(parked));
  });
}
