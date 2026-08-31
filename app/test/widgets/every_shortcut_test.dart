import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/canvas/geometry.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/find_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Every shortcut, pressed, on both kinds of keyboard.
///
/// There were tests for most of these and every one of them held ⌘. Which is
/// the modifier this app got wrong once already -- the bindings said `meta`
/// outright, so on Windows and Linux undo, redo, copy, paste and zoom did not
/// merely read wrong in the guide, they did nothing at all. The fix was to ask
/// the platform. Nothing then pressed Ctrl to see whether the fix worked, and
/// most people who can open this app are not on a Mac.
///
/// A second gap this closes: three bindings were never pressed anywhere.
/// Undo and redo -- the two every editor is judged on -- and zoom out, whose
/// key is the one next to the zoom-in key that was tested.
void main() {
  final canvasKey = GlobalKey<GraphCanvasState>();

  Future<PipelineController> pumpEditor(WidgetTester tester,
      {required bool apple}) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      apple: apple,
      canvasKey: canvasKey,
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();
    return controller;
  }

  /// Presses [key] with the modifier this keyboard holds shortcuts with.
  Future<void> press(WidgetTester tester, LogicalKeyboardKey key,
      {required bool apple, bool held = false, bool shift = false}) async {
    final modifier =
        apple ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control;
    if (held) await tester.sendKeyDownEvent(modifier);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (held) await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  /// Where a node sits, which is what the arrow keys and undo move.
  Offset at(PipelineController c, String id) {
    final node = c.pipeline.node(id)!;
    return Offset(node.x, node.y);
  }

  /// Where a nudge from [from] by [step] lands.
  ///
  /// Not `from + step`: a nudge moves *and then* snaps to the grid, so from a
  /// node that is off the grid the first press covers whatever distance the
  /// grid line is away and the ones after it are the full cell. That is the
  /// right behaviour -- an editor that snaps should end up snapped -- and it
  /// is why this is a function rather than a sum.
  Offset landing(Offset from, Offset step) => Offset(
        NodeLayout.snap(from.dx + step.dx),
        NodeLayout.snap(from.dy + step.dy),
      );

  // Both keyboards, the same expectations. Anything that reads `apple` below
  // is the binding under test; nothing else in the app should notice.
  for (final apple in [true, false]) {
    final board = apple ? 'a Mac keyboard' : 'a PC keyboard';

    group('on $board', () {
      testWidgets('undo takes back the last edit and redo puts it back',
          (tester) async {
        final controller = await pumpEditor(tester, apple: apple);
        final was = at(controller, 'elec');
        controller.selectNodes(['elec']);
        await tester.pump();

        final moved = landing(was, const Offset(8, 0));
        await press(tester, LogicalKeyboardKey.arrowRight, apple: apple);
        expect(at(controller, 'elec'), moved, reason: 'the edit to undo');

        await press(tester, LogicalKeyboardKey.keyZ, apple: apple, held: true);
        expect(at(controller, 'elec'), was, reason: 'undone');

        await press(tester, LogicalKeyboardKey.keyZ,
            apple: apple, held: true, shift: true);
        expect(at(controller, 'elec'), moved, reason: 'and back again');
      });

      testWidgets('delete and backspace both remove what is selected',
          (tester) async {
        for (final key in [
          LogicalKeyboardKey.delete,
          LogicalKeyboardKey.backspace,
        ]) {
          final controller = await pumpEditor(tester, apple: apple);
          final before = controller.pipeline.nodes.length;
          controller.selectNodes(['dupes']);
          await tester.pump();

          await press(tester, key, apple: apple);
          expect(controller.pipeline.nodes, hasLength(before - 1),
              reason: '$key removes the selected node');
        }
      });

      testWidgets('escape selects nothing', (tester) async {
        final controller = await pumpEditor(tester, apple: apple);
        controller.selectNodes(['elec']);
        await tester.pump();

        await press(tester, LogicalKeyboardKey.escape, apple: apple);
        expect(controller.selectedNodeIds, isEmpty);
      });

      testWidgets('all four zoom keys work the zoom', (tester) async {
        await pumpEditor(tester, apple: apple);
        expect(canvasKey.currentState!.scale, closeTo(1, 1e-9));

        await press(tester, LogicalKeyboardKey.equal, apple: apple, held: true);
        expect(canvasKey.currentState!.scale, closeTo(1.25, 1e-9),
            reason: 'zoom in');

        await press(tester, LogicalKeyboardKey.minus, apple: apple, held: true);
        expect(canvasKey.currentState!.scale, closeTo(1, 1e-9),
            reason: 'zoom out, which nothing had ever pressed');

        // The three spellings of plus. On a US or UK keyboard the + on the
        // main rows is ⇧=; on a number pad it is its own key; the bare `add`
        // is a keyboard where + needs no shift at all, and it is the only one
        // of the three that was bound. The test framework will not simulate
        // that last one -- it has no physical key to send it from -- which is
        // itself a fair sign of how few keyboards produce it.
        await press(tester, LogicalKeyboardKey.equal,
            apple: apple, held: true, shift: true);
        expect(canvasKey.currentState!.scale, closeTo(1.25, 1e-9),
            reason: 'the + you type by holding shift');

        await press(tester, LogicalKeyboardKey.numpadSubtract,
            apple: apple, held: true);
        expect(canvasKey.currentState!.scale, closeTo(1, 1e-9),
            reason: 'the number pad minus');

        await press(tester, LogicalKeyboardKey.numpadAdd,
            apple: apple, held: true);
        expect(canvasKey.currentState!.scale, closeTo(1.25, 1e-9),
            reason: 'the number pad plus');

        await press(tester, LogicalKeyboardKey.digit0,
            apple: apple, held: true);
        expect(canvasKey.currentState!.scale, closeTo(1, 1e-9),
            reason: 'back to life size');
      });

      testWidgets('find opens the search box', (tester) async {
        await pumpEditor(tester, apple: apple);
        expect(find.byType(FindPanel), findsNothing);

        await press(tester, LogicalKeyboardKey.keyF, apple: apple, held: true);
        expect(find.byType(FindPanel), findsOneWidget);
      });

      testWidgets('copy and paste carry nodes into the build', (tester) async {
        String? clipboard;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          if (call.method == 'Clipboard.getData') {
            return <String, Object?>{'text': clipboard};
          }
          return null;
        });
        addTearDown(() => TestDefaultBinaryMessengerBinding
            .instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null));

        final controller = await pumpEditor(tester, apple: apple);
        final before = controller.pipeline.nodes.length;
        controller.selectNodes(['elec']);
        await tester.pump();

        await press(tester, LogicalKeyboardKey.keyC, apple: apple, held: true);
        expect(clipboard, isNotNull, reason: 'copied');

        await press(tester, LogicalKeyboardKey.keyV, apple: apple, held: true);
        expect(controller.pipeline.nodes, hasLength(before + 1),
            reason: 'and pasted back in');
      });

      // A test each, rather than a loop inside one: pumping a second editor
      // into a live test leaves the arrow keys to the framework's own focus
      // traversal, which eats them before the canvas is asked. Delete and
      // backspace survive that because traversal has no use for them, so the
      // loop above is safe and this one was not -- and it failed loudly rather
      // than passing, which is the only reason it is written this way.
      for (final MapEntry(key: arrow, value: step) in <LogicalKeyboardKey,
          Offset>{
        LogicalKeyboardKey.arrowLeft: const Offset(-8, 0),
        LogicalKeyboardKey.arrowRight: const Offset(8, 0),
        LogicalKeyboardKey.arrowUp: const Offset(0, -8),
        LogicalKeyboardKey.arrowDown: const Offset(0, 8),
      }.entries) {
        for (final shift in [false, true]) {
          final cells = shift ? 8 : 1;
          testWidgets(
              '${arrow.keyLabel.toLowerCase()} moves $cells '
              '${cells == 1 ? 'cell' : 'cells'}', (tester) async {
            final controller = await pumpEditor(tester, apple: apple);
            final was = at(controller, 'elec');
            controller.selectNodes(['elec']);
            await tester.pump();

            await press(tester, arrow, apple: apple, shift: shift);
            expect(at(controller, 'elec'), landing(was, step * cells.toDouble()));
            expect(at(controller, 'elec'), isNot(was),
                reason: 'the press did something');
          });
        }
      }
    });
  }

  testWidgets('and none of them is bound to a key nothing presses',
      (tester) async {
    // The list above is written by hand, so it can fall behind the map. This
    // holds the two together: every activator the app binds is one this file
    // presses. It is the check that made the whole file worth writing: three
    // of the twenty bindings had no press anywhere in the suite, and pressing
    // them found that "⌘+" reached only one keyboard layout in three.
    final pressed = <String>{
      'Z', 'Z shift', 'Delete', 'Backspace', 'Escape',
      '=', '= shift', 'Numpad Add', '-', 'Numpad Subtract', '0',
      'F', 'C', 'V',
      for (final arrow in ['Arrow Left', 'Arrow Right', 'Arrow Up',
        'Arrow Down'])
        ...[arrow, '$arrow shift'],
    };
    final bound = <String>{
      for (final activator in editorShortcuts(apple: true).keys)
        if (activator is SingleActivator)
          '${activator.trigger.keyLabel}${activator.shift ? ' shift' : ''}',
    };
    // One binding cannot be pressed here, and is named rather than quietly
    // added to the list above: no physical key sends a bare `+`, so the test
    // framework refuses to simulate it. It stays bound for the keyboards that
    // do produce it -- German, Scandinavian -- where + needs no shift.
    expect(bound.difference(pressed), {'+'},
        reason: 'a binding this file does not press');
    expect(pressed.difference(bound), isEmpty,
        reason: 'a press for a binding that no longer exists');
  });
}
