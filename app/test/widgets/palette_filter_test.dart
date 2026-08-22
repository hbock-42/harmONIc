import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/display_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/panels/palette_panel.dart';
import 'package:oni_pipeline/panels/process_editor.dart';

import '../support/harness.dart';

void main() {
  Future<DisplayController> pumpEditor(
    WidgetTester tester, {
    DisplayController? display,
  }) async {
    await useDesktopSurface(tester);
    final controller = testController();
    final settings = display ?? testDisplay();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: settings,
    )));
    return settings;
  }

  /// The palette's own search box; the top bar has a text field too.
  Finder paletteSearch() => find.descendant(
        of: find.byType(PalettePanel),
        matching: find.byType(OniField),
      );

  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(find.textContaining('SHOWING'));
    await tester.pump();
  }

  testWidgets('everything is offered until you say otherwise', (tester) async {
    await pumpEditor(tester);

    expect(textContaining('everything'), findsOneWidget);
    await openFilters(tester);
    expect(find.text('Aquatic'), findsOneWidget);
    expect(find.text('Wild'), findsOneWidget);
  });

  testWidgets('turning a pack off takes its content out of the list',
      (tester) async {
    final display = await pumpEditor(tester);
    await openFilters(tester);

    await tester.tap(find.text('Aquatic'));
    await tester.pump();

    expect(display.packEnabled('aquatic'), isFalse);
    // And says how much is being kept back, so a filter set last week is not
    // mistaken for an empty database.
    expect(textContaining('hidden'), findsOneWidget);

    await tester.enterText(paletteSearch(), 'Tidal');
    await tester.pump();
    expect(find.text('Tidal Turbine'), findsNothing);
  });

  testWidgets('a search still finds base-game content with a pack off',
      (tester) async {
    final display = await pumpEditor(tester);
    await display.setPack('aquatic', enabled: false);
    await tester.pump();

    await tester.enterText(paletteSearch(), 'Electrolyzer');
    await tester.pump();
    expect(find.text('Electrolyzer'), findsWidgets);
  });

  testWidgets('hiding wild variants halves the critter list', (tester) async {
    final display = await pumpEditor(tester);

    await tester.enterText(paletteSearch(), 'Hatch');
    await tester.pump();
    final withWild = find.textContaining('Hatch').evaluate().length;

    await display.setShowWild(showWild: false);
    await tester.pump();
    final without = find.textContaining('Hatch').evaluate().length;

    expect(without, lessThan(withWild));
    expect(find.text('Hatch (wild)'), findsNothing);
    expect(find.text('Hatch'), findsWidgets);
  });

  testWidgets('the choice outlives the session', (tester) async {
    final store = MemoryJsonStore();
    final first = DisplayController(store);
    await first.load();
    await first.setPack('frosty', enabled: false);
    await first.setShowWild(showWild: false);

    final second = DisplayController(store);
    await second.load();

    expect(second.packEnabled('frosty'), isFalse);
    expect(second.packEnabled('aquatic'), isTrue);
    expect(second.showWild, isFalse);
  });

  testWidgets('a pack switched off is kept out of the recipe editor too',
      (tester) async {
    final display = await pumpEditor(tester);
    await display.setPack('aquatic', enabled: false);
    await tester.pump();

    await tester.tap(find.text('+ Recipe'));
    await tester.pump();
    await tester.enterText(
        find.descendant(
                of: find.byType(ProcessEditor), matching: find.byType(OniField))
            .first,
        'Test recipe');
    await tester.pump();
    await tester.tap(find.text('+ Consumes'));
    await tester.pump();
    await tester.tap(find.text('Choose an item…'));
    await tester.pump();

    // Base-game materials are offered as before...
    await tester.enterText(find.byKey(itemPickerSearchKey), 'Phosphorite');
    await tester.pump();
    expect(textLabel('Phosphorite'), findsWidgets);

    // ...and Aquatic ones are not, with the pack switched off. find.text would
    // also match the search box's own contents, hence the rendered-label
    // predicate.
    await tester.enterText(find.byKey(itemPickerSearchKey), 'Coquina');
    await tester.pump();
    expect(textLabel('Coquina'), findsNothing);
  });

  testWidgets('a supply node is as optional as the thing it supplies',
      (tester) async {
    final display = await pumpEditor(tester);
    await openFilters(tester);
    await tester.tap(find.text('Aquatic'));
    await tester.pump();
    expect(display.packEnabled('aquatic'), isFalse);

    await tester.enterText(paletteSearch(), 'Coquina');
    await tester.pump();
    expect(textLabel('Coquina supply'), findsNothing);

    await tester.enterText(paletteSearch(), 'Water supply');
    await tester.pump();
    expect(textLabel('Water supply'), findsWidgets);
  });

  testWidgets('filters get a group of their own, like pumps', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(paletteSearch(), 'Oxygen filter');
    await tester.pump();

    expect(find.text('FILTERING'), findsOneWidget);
    expect(textLabel('Oxygen filter'), findsWidgets);
  });

  testWidgets('Spaced Out is a pack you can turn off like the others',
      (tester) async {
    final display = await pumpEditor(tester);
    await openFilters(tester);
    expect(find.text('Spaced Out'), findsOneWidget);

    // A Plug Slug belongs to the DLC the three planet packs sit on, and
    // somebody playing the base game cannot have one.
    expect(display.includes(testDatabase.processOrThrow('plug_slug')),
        isTrue);

    await tester.tap(find.text('Spaced Out'));
    await tester.pump();

    expect(display.includes(testDatabase.processOrThrow('plug_slug')),
        isFalse);
    expect(display.includesItem(testDatabase.itemOrThrow('sucrose')), isFalse);
    // And nothing base-game goes with it.
    expect(display.includesItem(testDatabase.itemOrThrow('water')), isTrue);
    expect(display.includes(testDatabase.processOrThrow('electrolyzer')),
        isTrue);
  });
}