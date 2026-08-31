import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/panels/palette_panel.dart';
import 'package:oni_pipeline/state/display_controller.dart';

import '../support/harness.dart';

/// Everything added this week can actually be found and placed.
///
/// Adding a recipe to the data and adding it to the app are not the same
/// thing: a spec with a tag nothing groups by, or belonging to a pack nothing
/// offers, is in the database and nowhere a person can reach.
void main() {
  Future<DisplayController> open(WidgetTester tester,
      {String? search, DisplayController? display}) async {
    await useDesktopSurface(tester);
    final settings = display ?? testDisplay();
    await tester.pumpWidget(harness(listening(
      settings,
      (_) => PalettePanel(
        database: testDatabase,
        display: settings,
        onAdd: (_) {},
        onNewRecipe: () {},
        onEditRecipe: (_) {},
      ),
    )));
    await tester.pumpAndSettle();
    if (search != null) {
      await tester.enterText(paletteSearch(), search);
      await tester.pumpAndSettle();
    }
    return settings;
  }

  for (final (name, query) in const [
    ('Volcano', 'volcano'),
    ('Minor Volcano', 'minor volcano'),
    ('Sour Gas Boiler', 'sour gas'),
    ('Critter Fountain', 'critter fountain'),
    ('Gleaner (Brackene)', 'gleaner'),
    ('Bionic Duplicant', 'bionic'),
    ('Plant Pulverizer (Nosh Bean)', 'nosh bean'),
  ]) {
    testWidgets('$name is in the palette', (tester) async {
      await open(tester, search: query);
      expect(find.text(name), findsOneWidget, reason: query);
    });
  }

  testWidgets('the Bionic pack can be turned off, and takes its own with it',
      (tester) async {
    final display = await open(tester, search: 'bionic');
    expect(find.text('Bionic Duplicant'), findsOneWidget);

    await display.setPack('bionic', enabled: false);
    await tester.pumpAndSettle();
    expect(find.text('Bionic Duplicant'), findsNothing);
  });

  testWidgets('and turning it off leaves the base game alone', (tester) async {
    // Phyto Oil came with that pack and belongs to everybody now, so the
    // Plant Pulverizer that makes it must not go with it.
    final display = await open(tester, display: testDisplay());
    await display.setPack('bionic', enabled: false);
    await tester.enterText(paletteSearch(), 'plant pulverizer');
    await tester.pumpAndSettle();
    expect(find.textContaining('Plant Pulverizer'), findsWidgets);
  });
}
