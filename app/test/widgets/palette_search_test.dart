import 'package:oni_engine/oni_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/palette_panel.dart';

import '../support/harness.dart';

/// Searching the palette for a material rather than for a name.
///
/// "What makes oxygen?" is the first question anybody asks a production
/// planner, and the list matched names only — so the Electrolyzer, which is
/// the answer, was not in it.
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

  Finder inPalette(Finder matching) =>
      find.descendant(of: find.byType(PalettePanel), matching: matching);

  testWidgets('a material finds what makes it', (tester) async {
    await pumpEditor(tester);
    await search(tester, 'oxygen');

    expect(inPalette(textLabel('Electrolyzer')), findsOneWidget);
    // And says why it is in the list, since the name does not say so.
    expect(inPalette(find.text('makes oxygen')), findsWidgets);
  });

  testWidgets('and what eats it, said differently', (tester) async {
    await pumpEditor(tester);
    await search(tester, 'coal');

    // A Coal Generator matched by name; a Hatch matched by what it makes.
    expect(inPalette(textLabel('Coal Generator')), findsOneWidget);
    expect(inPalette(textLabel('Hatch')), findsWidgets);
    expect(inPalette(find.text('makes coal')), findsWidgets);
  });

  testWidgets('and a name-only match says nothing extra', (tester) async {
    await pumpEditor(tester);
    await search(tester, 'Electrolyzer');

    expect(inPalette(textLabel('Electrolyzer')), findsOneWidget);
    expect(inPalette(find.text('makes oxygen')), findsNothing);
  });

  testWidgets('nonsense still finds nothing', (tester) async {
    await pumpEditor(tester);
    await search(tester, 'unobtanium');

    expect(inPalette(textLabel('Electrolyzer')), findsNothing);
  });

  group('the ranking, on its own', () {
    final db = testDatabase;
    ProcessSpec spec(String id) => db.processOrThrow(id);

    test('a name beats what makes it, which beats what eats it', () {
      // "Oxygen Diffuser" is a name; an Electrolyzer makes oxygen; a
      // Duplicant breathes it. Somebody typing "oxygen" wants them in that
      // order, and a Coal Generator not at all.
      expect(paletteRank(spec('oxygen_diffuser'), 'oxygen', db), 0);
      expect(paletteRank(spec('electrolyzer'), 'oxygen', db), 1);
      expect(paletteRank(spec('duplicant'), 'oxygen', db), 2);
      expect(paletteRank(spec('coal_generator'), 'oxygen', db), 3);
    });

    test('and the reason is said in the words of what it does', () {
      expect(paletteWhy(spec('electrolyzer'), 'oxygen', db), 'makes oxygen');
      expect(paletteWhy(spec('electrolyzer'), 'water', db), 'takes water');
      // A name match explains itself, so it says nothing.
      expect(paletteWhy(spec('water_sieve'), 'water', db), isNull);
      expect(paletteWhy(spec('electrolyzer'), '', db), isNull);
    });

    test('making beats taking when it does both', () {
      // A Metal Refinery takes water as coolant and gives it back hotter. It
      // is a *source* of hot water as far as a search is concerned.
      expect(paletteWhy(spec('metal_refinery'), 'water', db), 'makes water');
    });
  });
}
