import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';
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

  /// Narrow before looking: the panel opens on everything, and a list of
  /// hundreds keeps what a test is after below the fold.
  Future<void> family(WidgetTester tester, String label) async {
    await tester.tap(find.textContaining(label).first);
    await tester.pumpAndSettle();
  }

  /// Drag until it is built. A lazy list has not made what is below the fold,
  /// so a finder for it comes back empty rather than merely off screen.
  Future<void> scrollTo(WidgetTester tester, Key key) async {
    for (var i = 0; i < 60; i++) {
      if (find.byKey(key).evaluate().isNotEmpty) {
        await tester.ensureVisible(find.byKey(key));
        await tester.pumpAndSettle();
        return;
      }
      await tester.drag(
        find.descendant(
          of: find.byType(CataloguePanel),
          matching: find.byType(ListView),
        ),
        const Offset(0, -300),
      );
      await tester.pump();
    }
    fail('never scrolled as far as $key');
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
    await family(tester, 'Critters');
    await search(tester, 'dirt');

    // Per cycle, which is how the game quotes a critter: a Pip makes 20 kg of
    // dirt a cycle, not 33 grams a second.
    expect(textContaining('Pip'), findsWidgets);
    expect(textContaining('20.00 kg'), findsWidgets);
  });

  testWidgets('and says which figures are a judgement', (tester) async {
    await pumpCatalogue(tester);
    await family(tester, 'Critters');
    await search(tester, 'iron ore');

    expect(textContaining('Orehull'), findsWidgets);
    // "Judged" rather than "unverified": the reader has not met that word and
    // what it means is that somebody decided the figure rather than read it.
    expect(textContaining('judged'), findsWidgets);
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
    await family(tester, 'Critters');
    await search(tester, 'iron ore');

    // On the card rather than on hover: something you can see is there is
    // something somebody will use.
    await scrollTo(tester, const ValueKey('wrong:iron_ore:orehull'));
    await tester.tap(find.byKey(const ValueKey('wrong:iron_ore:orehull')));
    await tester.pumpAndSettle();

    expect(reported?.id, 'orehull');
  });

  testWidgets('and it is a button on the toolbar, not a page in the guide',
      (tester) async {
    // Checking a figure is not reading the manual: it happens mid-build, when
    // a number on the canvas looks wrong, and it was two clicks deep inside
    // the guide.
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));

    await tester.ensureVisible(find.text('Figures'));
    await tester.pump();
    await tester.tap(find.text('Figures'));
    await tester.pumpAndSettle();

    expect(find.byType(CataloguePanel), findsOneWidget);
  });

  testWidgets('turns round to say what eats a thing', (tester) async {
    // The half that was missing: an Orehull eating 20 kg of nori a cycle
    // means nothing on its own and something beside everything else that
    // eats nori.
    await pumpCatalogue(tester);
    await family(tester, 'Critters');
    await tester.tap(find.text('What eats it'));
    await tester.pumpAndSettle();
    await search(tester, 'nori');

    expect(textContaining('Orehull'), findsWidgets);
    // And what the eating buys, so the cost has something beside it.
    expect(textContaining('Iron Ore'), findsWidgets);
  });

  testWidgets('scales one card at a time, for checking a ratio', (tester) async {
    // Per card rather than across the page: comparing two ways of getting a
    // thing means holding one still while the other moves.
    await pumpCatalogue(tester);
    await family(tester, 'Critters');
    await search(tester, 'dirt');
    // A Slogo gives 50 kg of dirt a cycle and is the largest, so it leads.
    expect(textContaining('50.00 kg'), findsWidgets);

    await scrollTo(tester, const ValueKey('times:dirt:slogo:5'));
    await tester.tap(find.byKey(const ValueKey('times:dirt:slogo:5')));
    await tester.pumpAndSettle();

    expect(textContaining('250.00 kg'), findsWidgets);
  });

  testWidgets('and shows one recipe whole, with what it does to matter',
      (tester) async {
    await pumpCatalogue(tester);
    await family(tester, 'Critters');
    await search(tester, 'coal');
    await scrollTo(tester, const ValueKey('inspect:coal:hatch'));
    await tester.tap(find.byKey(const ValueKey('inspect:coal:hatch')));
    await tester.pumpAndSettle();

    expect(find.text('TAKES'), findsOneWidget);
    expect(find.text('GIVES'), findsOneWidget);
    // A Hatch gives back half of what it eats, which is the point of it.
    expect(textContaining('WHAT IT DOES TO MATTER'), findsOneWidget);
    expect(textContaining('kg in'), findsOneWidget);
  });

  testWidgets('and keeps the judged figures apart from the published ones',
      (tester) async {
    await pumpCatalogue(tester);
    await family(tester, 'Critters');
    await tester.tap(find.text('Judged'));
    await tester.pumpAndSettle();
    await search(tester, 'iron ore');

    expect(textContaining('Orehull'), findsWidgets);

    await tester.tap(find.text('Published'));
    await tester.pumpAndSettle();

    expect(textContaining('Orehull'), findsNothing);
  });

}
