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
    for (var i = 0; i < 60; i++) {
      if (inPalette(textLabel(label)).evaluate().isNotEmpty) return;
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
    // Folded means folded: SUPPLY and OUTPUT are 428 rows between them, and
    // both headers are on screen together with nothing in between.
    expect(inPalette(textLabel('OUTPUT')), findsOneWidget);
    expect(inPalette(textLabel('Water supply')), findsNothing);
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
