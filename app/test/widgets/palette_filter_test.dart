import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/display_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/panels/palette_panel.dart';

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
}
