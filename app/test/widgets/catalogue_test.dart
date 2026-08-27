import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/panels/catalogue_panel.dart';

import '../support/harness.dart';

/// Every figure the app uses, for somebody checking them.
///
/// Built from the database the app is running on. There is no second copy of
/// the data anywhere — the first attempt at this generated a Markdown file,
/// which is a duplicate of the thing it describes and a page nobody reads.
void main() {
  Future<void> pumpCatalogue(WidgetTester tester) async {
    await useDesktopSurface(tester);
    await tester.pumpWidget(harness(CataloguePanel(
      database: testDatabase,
      onClose: () {},
    )));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(CataloguePanel),
        matching: find.byType(OniField),
      ),
      query,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows what makes a thing, in the game\'s own units',
      (tester) async {
    await pumpCatalogue(tester);
    await search(tester, 'dirt');

    // Per cycle, which is how the game quotes a critter: a Pip makes 20 kg of
    // dirt a cycle, not 33 grams a second.
    expect(textContaining('Pip'), findsWidgets);
    expect(textContaining('20.00 kg'), findsWidgets);
  });

  testWidgets('and says which figures are a judgement', (tester) async {
    await pumpCatalogue(tester);
    await search(tester, 'iron ore');

    expect(textContaining('Orehull'), findsWidgets);
    expect(textContaining('unverified'), findsWidgets);
  });

  testWidgets('and offers to say a figure is wrong', (tester) async {
    ProcessSpec? reported;
    await useDesktopSurface(tester);
    await tester.pumpWidget(harness(CataloguePanel(
      database: testDatabase,
      onClose: () {},
      onReport: (spec) => reported = spec,
    )));
    await tester.pumpAndSettle();
    await search(tester, 'iron ore');

    // The affordance appears on hover, where the row is.
    final row = find.ancestor(
      of: textContaining('Orehull'),
      matching: find.byType(MouseRegion),
    );
    final gesture =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(row.first));
    addTearDown(gesture.removePointer);
    await tester.pumpAndSettle();

    await tester.tap(find.text('wrong?').first);
    await tester.pumpAndSettle();

    expect(reported?.id, 'orehull');
  });
}
