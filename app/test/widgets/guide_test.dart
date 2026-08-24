import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/guide_panel.dart';
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
      // The real text, read off the disk rather than out of the asset bundle,
      // and read *synchronously*: a widget test pumps fake time and flushes
      // microtasks, and never waits on real I/O. An async read would still be
      // in flight when the assertions ran, and the guide would look empty for
      // reasons that have nothing to do with the guide.
      loadGuide: () async => File('assets/using.md').readAsStringSync(),
    )));
    return controller;
  }

  Future<void> openGuide(WidgetTester tester) async {
    await tester.ensureVisible(find.text('?'));
    await tester.pump();
    await tester.tap(find.text('?'));
    await tester.pumpAndSettle();
  }

  testWidgets('the guide opens from the toolbar and closes again',
      (tester) async {
    await pumpEditor(tester);
    await openGuide(tester);

    expect(find.byType(GuidePanel), findsOneWidget);
    expect(find.text('HOW THIS WORKS'), findsOneWidget);
    // Bold becomes spans rather than a Text with data, hence findRichText.
    expect(
        find.textContaining('draw what you are building', findRichText: true),
        findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(GuidePanel), findsNothing);
  });

  testWidgets('headings and bullets come out as headings and bullets',
      (tester) async {
    await pumpEditor(tester);
    await openGuide(tester);

    // A heading from the document, rendered as a heading rather than as the
    // characters "## Drawing a build".
    expect(find.text('Drawing a build'), findsOneWidget);
    expect(find.textContaining('##', findRichText: true), findsNothing);
  });

  testWidgets('a guide that will not load says so rather than looking empty',
      (tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
      loadGuide: () async => throw const FileSystemException('no such asset'),
    )));
    await openGuide(tester);

    expect(textContaining('The guide did not load'), findsOneWidget);
    expect(textContaining('docs/USING.md'), findsOneWidget);
  });

  test('the shipped guide is the one in docs, to the byte', () {
    // The app cannot read a file outside its own package, so the guide is
    // copied into the assets by tool/copy_docs.sh. Two copies of anything
    // drift; this is what stops them.
    final shipped = File('assets/using.md').readAsStringSync();
    final canonical = File('../docs/USING.md').readAsStringSync();
    expect(shipped, canonical,
        reason: 'run tool/copy_docs.sh — the app ships a stale guide');
  });

  testWidgets('and clicking away closes it too', (tester) async {
    await pumpEditor(tester);
    await openGuide(tester);
    expect(find.byType(GuidePanel), findsOneWidget);

    // The dimmed area around the panel. The pipelines menu and the recipe
    // form have always closed this way; the guide was the odd one out, and a
    // panel you can only dismiss by finding its one button is a panel people
    // leave open.
    await tester.tapAt(const Offset(40, 500));
    await tester.pumpAndSettle();

    expect(find.byType(GuidePanel), findsNothing);
  });

  testWidgets('but reading it does not', (tester) async {
    await pumpEditor(tester);
    await openGuide(tester);

    // A click on the panel itself — on its own text — must not shut it.
    await tester.tap(find.textContaining('The whole app is one idea'));
    await tester.pumpAndSettle();
    expect(find.byType(GuidePanel), findsOneWidget);

    // Nor does dragging inside it, which is how somebody scrolls.
    await tester.drag(
        find.textContaining('The whole app is one idea'), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(find.byType(GuidePanel), findsOneWidget);
  });
}
