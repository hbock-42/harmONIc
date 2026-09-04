import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/palette_panel.dart';

import '../support/harness.dart';

/// Folding the palette's groups away.
///
/// The database generates a supply and an output node for every item and an
/// eating node for every food, which is 428 of the roughly 700 rows in the
/// list. None of them is what somebody opening the palette is looking for, and
/// all of them are between them and the buildings that are.
void main() {
  Future<void> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
  }

  Finder inPalette(Finder matching) =>
      find.descendant(of: find.byType(PalettePanel), matching: matching);

  /// The palette's own list, which is long enough that a header far down it
  /// has not been built yet.
  Future<void> scrollTo(WidgetTester tester, String label) async {
    // Sixty 300-pixel drags was enough until it was not: "Water supply" sorts
    // near the end of 214 supply rows, and two plants added elsewhere pushed
    // it past the limit. The bound is only here so a label that never arrives
    // fails instead of hanging.
    for (var i = 0; i < 200; i++) {
      if (inPalette(textLabel(label)).evaluate().isNotEmpty) {
        // Built is not the same as on screen. A lazy list builds a little
        // beyond the fold, so this used to stop with the row it was looking
        // for sitting at the very bottom edge or just past it -- near enough
        // to find, too far to tap. Two extra plants elsewhere in the list were
        // enough to turn that into a failure.
        await tester.ensureVisible(inPalette(textLabel(label)));
        await tester.pumpAndSettle();
        return;
      }
      await tester.drag(
          inPalette(find.byType(ListView)), const Offset(0, -300));
      await tester.pump();
    }
    fail('never scrolled as far as $label');
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(PalettePanel),
        matching: find.byType(OniField),
      ),
      query,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the one-per-item groups start folded', (tester) async {
    await pumpEditor(tester);

    // A building group is open, because that is what the palette is for.
    // COLONY is the first of them, and the Duplicant is in it.
    expect(inPalette(textLabel('Duplicant')), findsOneWidget);
    // The whole rest of the list fits above the fold only because 428 rows
    // are folded away: reaching SUPPLY at all is the point of the change.
    await scrollTo(tester, 'SUPPLY');
    // Folded means folded: there are 428 rows between SUPPLY and OUTPUT, and
    // getting from one to the other takes a drag at most.
    //
    // It used to require both headers on screen at once, which was true until
    // two plants were added somewhere above and pushed OUTPUT a row past the
    // fold. The claim was never about them sharing a screen; it is that the
    // rows between them are not there.
    var drags = 0;
    while (inPalette(textLabel('OUTPUT')).evaluate().isEmpty) {
      drags++;
      expect(drags, lessThanOrEqualTo(1),
          reason: 'OUTPUT is more than one screen below SUPPLY, so something '
              'between them is unfolded');
      await tester.drag(
          inPalette(find.byType(ListView)), const Offset(0, -300));
      await tester.pump();
    }
    expect(inPalette(textLabel('Water supply')), findsNothing,
        reason: 'and none of the folded rows was drawn on the way');
  });

  testWidgets('and open when the header is tapped', (tester) async {
    await pumpEditor(tester);
    await scrollTo(tester, 'SUPPLY');
    await tester.tap(inPalette(textLabel('SUPPLY')));
    await tester.pumpAndSettle();

    // The rows are there now — far down the group, since it is sorted by
    // name and there are 214 of them.
    await scrollTo(tester, 'Water supply');
    expect(inPalette(textLabel('Water supply')), findsOneWidget);
  });

  testWidgets('a search shows what it found, folded or not', (tester) async {
    await pumpEditor(tester);
    // Nothing was unfolded first: a search that could not show its own
    // results would be worse than no folding at all.
    await search(tester, 'water supply');

    expect(inPalette(textLabel('Water supply')), findsOneWidget);
  });

  testWidgets('and folds back afterwards, not staying open', (tester) async {
    await pumpEditor(tester);
    await search(tester, 'water supply');
    await search(tester, '');

    expect(inPalette(textLabel('Water supply')), findsNothing);
  });
}
