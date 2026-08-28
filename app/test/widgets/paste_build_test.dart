import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/design/tokens.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Getting a build in, when the clipboard will not have it.
///
/// Reported: "I cannot use it and I have no error message when clicking the
/// paste build button". The code in question was damaged — one character of
/// four hundred and eighty had changed in transit — and the app had two ways
/// of saying nothing about it: a clipboard the browser would not read, and a
/// failure that said the code was not a code.
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pipelines'));
    await tester.pumpAndSettle();
    return controller;
  }

  String aCode() => PipelineShareCode.encode(testPipeline());

  testWidgets('a code typed into the box opens the build', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('paste-code')),
            matching: find.byType(EditableText)),
        aCode());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // The menu closes on success, which is how it says so.
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('and a damaged one says it is damaged', (tester) async {
    await pumpEditor(tester);
    final code = aCode();
    // One character, the way it happens: a copy that lost something.
    final broken =
        code.replaceRange(20, 21, code[20] == 'A' ? 'B' : 'A');

    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('paste-code')),
            matching: find.byType(EditableText)),
        broken);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(textContaining('it is damaged'), findsOneWidget);
  });

  testWidgets('and something that was never a code says that instead',
      (tester) async {
    await pumpEditor(tester);

    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('paste-code')),
            matching: find.byType(EditableText)),
        'hello');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(textContaining('not a share code'), findsOneWidget);
  });

  testWidgets('and a failure is said in the failure colour, next to the box',
      (tester) async {
    // Reported from a screenshot: the message sat under a fold about recipes,
    // in the same grey as "Share code copied." — a sentence about what just
    // went wrong, printed somewhere else and dressed as a note.
    await pumpEditor(tester);
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('paste-code')),
            matching: find.byType(EditableText)),
        'hello');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final said = textContaining('not a share code');
    expect(said, findsOneWidget);
    expect(
      (tester.widget<Text>(said).style?.color),
      OniColors.danger,
    );
    // Above the recipes fold, not below it.
    expect(tester.getTopLeft(said).dy,
        lessThan(tester.getTopLeft(find.text('Recipes you wrote')).dy));
  });

  testWidgets('and a code cut short says it was cut short', (tester) async {
    // The likeliest thing to happen to four hundred characters on one line.
    await pumpEditor(tester);
    final code = aCode();
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('paste-code')),
            matching: find.byType(EditableText)),
        code.substring(0, code.length - 40));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(textContaining('stops in the middle'), findsOneWidget);
  });
}
