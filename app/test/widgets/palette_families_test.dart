import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/panels/palette_panel.dart';

import '../support/harness.dart';

/// One row per thing, not one per way of keeping it.
///
/// Sixty-five of the cards in this catalogue were a second copy of another
/// differing by one switch, so the list was nearly twice as long as it needed
/// to be for no information at all. The other ways are on the card once it is
/// placed.
void main() {
  Future<void> open(WidgetTester tester, {String? search}) async {
    await useDesktopSurface(tester);
    await tester.pumpWidget(harness(PalettePanel(
      database: testDatabase,
      display: testDisplay(),
      onAdd: (_) {},
      onNewRecipe: () {},
      onEditRecipe: (_) {},
    )));
    await tester.pumpAndSettle();
    if (search != null) {
      await tester.enterText(paletteSearch(), search);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the wild twin is not a second row', (tester) async {
    await open(tester, search: 'hatch');
    expect(find.text('Hatch'), findsOneWidget);
    expect(find.text('Hatch (wild)'), findsNothing,
        reason: 'it is a switch on the card, not a card of its own');
  });

  testWidgets('but asking for it by name finds it', (tester) async {
    // The whole rule: folding a card away must never make it unfindable.
    await open(tester, search: 'hatch (wild)');
    expect(find.text('Hatch (wild)'), findsOneWidget);
  });

  testWidgets('and searching for what makes them different finds them',
      (tester) async {
    await open(tester, search: 'wild');
    expect(find.text('Hatch (wild)'), findsOneWidget);
    expect(find.text('Hatch'), findsNothing,
        reason: 'the tame one is not what was asked for');
  });

  testWidgets('an Arbor Tree is one row, not four', (tester) async {
    await open(tester, search: 'arbor tree');
    expect(find.text('Arbor Tree'), findsOneWidget);
    for (final other in [
      'Arbor Tree (grazed)',
      'Arbor Tree (wild)',
      'Arbor Tree (wild, grazed)',
    ]) {
      expect(find.text(other), findsNothing, reason: other);
    }
  });

  testWidgets('and a thing with no other way is untouched', (tester) async {
    await open(tester, search: 'electrolyzer');
    expect(find.text('Electrolyzer'), findsOneWidget);
  });
}
