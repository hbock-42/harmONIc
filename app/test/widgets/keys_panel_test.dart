import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/keys_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// The card of keys: one button, and one key you hold.
void main() {
  Future<PipelineController> pumpEditor(WidgetTester tester,
      {bool apple = true}) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      apple: apple,
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  testWidgets('the button opens it and it stays open', (tester) async {
    await pumpEditor(tester);
    expect(find.byType(KeysPanel), findsNothing);

    await tester.ensureVisible(find.text('Keys  ?'));
    await tester.pump();
    await tester.tap(find.text('Keys  ?'));
    await tester.pumpAndSettle();

    expect(find.byType(KeysPanel), findsOneWidget);
    // Pairs, not prose: what to press on the left, what it does on the right.
    expect(find.text('undo'), findsOneWidget);
    expect(find.text('copy and paste nodes'), findsOneWidget);
    expect(find.text('EDITING'), findsOneWidget);

    // Opened this way it waits to be dismissed.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(KeysPanel), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(KeysPanel), findsNothing);
  });

  testWidgets('and clicking away closes it', (tester) async {
    await pumpEditor(tester);
    await tester.ensureVisible(find.text('Keys  ?'));
    await tester.pump();
    await tester.tap(find.text('Keys  ?'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(40, 500));
    await tester.pumpAndSettle();
    expect(find.byType(KeysPanel), findsNothing);
  });

  testWidgets('holding ? shows it, and letting go puts it away',
      (tester) async {
    await pumpEditor(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.slash);
    await tester.pump();
    expect(find.byType(KeysPanel), findsOneWidget);
    // Nothing to press while it is held: there is a key under your finger
    // doing the job, and a Close button would only be in the way.
    expect(find.text('Close'), findsNothing);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);
    await tester.pump();
    expect(find.byType(KeysPanel), findsNothing);
  });

  testWidgets('and holding it makes no noise', (tester) async {
    // macOS beeps at every key event nothing claims, and holding a key sends
    // a repeat every few dozen milliseconds. Claiming the down and the up and
    // ignoring the repeats sounded exactly like the app refusing the key.
    await pumpEditor(tester);

    expect(await tester.sendKeyDownEvent(LogicalKeyboardKey.slash), isTrue);
    for (var i = 0; i < 5; i++) {
      expect(await tester.sendKeyRepeatEvent(LogicalKeyboardKey.slash), isTrue,
          reason: 'repeat $i');
    }
    await tester.pump();
    expect(find.byType(KeysPanel), findsOneWidget,
        reason: 'and the repeats change nothing');

    expect(await tester.sendKeyUpEvent(LogicalKeyboardKey.slash), isTrue);
    await tester.pump();
    expect(find.byType(KeysPanel), findsNothing);
  });

  testWidgets('and shift does not confuse it', (tester) async {
    // ? is shift and / on most keyboards. Letting go of shift first must not
    // leave the card on screen, which is why the physical key is watched.
    await pumpEditor(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.slash);
    await tester.pump();
    expect(find.byType(KeysPanel), findsOneWidget);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.byType(KeysPanel), findsOneWidget, reason: 'still held');

    await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);
    await tester.pump();
    expect(find.byType(KeysPanel), findsNothing);
  });

  test('the card says the same as the guide', () {
    // Eleven lines against nineteen bindings: four arrows are one line, two
    // ways to delete are one. What must not happen is a key on the card that
    // the app does not answer to.
    final onCard = <String>[
      for (final (_, lines) in kKeyGroups)
        for (final (keys, _) in lines) keys,
    ];
    expect(onCard, contains('⌘Z'));
    expect(onCard, contains('esc'));
    expect(onCard.length, greaterThan(8));

    for (final key in kShortcutNames.keys) {
      // Every key the guide names appears on the card, allowing for the ones
      // the card pairs up on one line.
      expect(onCard.join(' '), contains(key.split(' ').first), reason: key);
    }
  });

  testWidgets('the key and what it does sit on one line', (tester) async {
    // They are set in different faces at different sizes, so aligning the
    // boxes leaves the keys riding high above the words. The letters have to
    // sit on the same baseline, which is a different thing.
    await pumpEditor(tester);
    await tester.ensureVisible(find.text('Keys  ?'));
    await tester.pump();
    await tester.tap(find.text('Keys  ?'));
    await tester.pumpAndSettle();

    final key = tester.getRect(find.text('⌘Z'));
    final does = tester.getRect(find.text('undo'));
    expect((key.center.dy - does.center.dy).abs(), lessThan(1.5),
        reason: 'the two columns of one row are level');
  });

  testWidgets('and both panels open against the right edge', (tester) async {
    // The canvas is what somebody is reading these *about*; a centred slab
    // covers the build being explained.
    await pumpEditor(tester);
    await tester.ensureVisible(find.text('Keys  ?'));
    await tester.pump();
    await tester.tap(find.text('Keys  ?'));
    await tester.pumpAndSettle();

    // The palette and the inspector are OniPanels too; this is the one
    // inside the card.
    final panel = tester.getRect(find.descendant(
      of: find.byType(KeysPanel),
      matching: find.byType(OniPanel),
    ));
    final screen = tester.getRect(find.byType(KeysPanel));
    expect(screen.right - panel.right, lessThan(1),
        reason: 'flush against the right edge, no margin');
    expect(panel.left, greaterThan(screen.width / 2),
        reason: 'and out of the way of the canvas');
  });
  testWidgets('and it is spelled for the keyboard in front of you',
      (tester) async {
    // The card was written on a Mac and said ⌘ to everybody. Half the people
    // who can open this in a browser have no such key, and for them the
    // shortcut is Ctrl — which it now both says and answers to.
    await pumpEditor(tester, apple: false);
    await tester.ensureVisible(find.text('Keys  ?'));
    await tester.tap(find.text('Keys  ?'));
    await tester.pumpAndSettle();

    expect(find.text('Ctrl+Z'), findsOneWidget);
    expect(find.text('Ctrl+Shift+Z'), findsOneWidget);
    expect(find.text('⌘Z'), findsNothing);
    // And what is the same everywhere is left alone.
    expect(find.text('esc'), findsOneWidget);
  });

}
