import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/design/tokens.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/display_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

void main() {
  setUp(() => OniTheme.current = OniPalette.dark);
  tearDown(() => OniTheme.current = OniPalette.dark);

  Future<DisplayController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    final display = testDisplay();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: display,
    )));
    return display;
  }

  testWidgets('the switch says which way it takes you', (tester) async {
    final display = await pumpEditor(tester);

    // Dark to begin with, so the button offers the sun.
    expect(display.isLight, isFalse);
    await tester.ensureVisible(find.text('☀'));
    await tester.pump();
    await tester.tap(find.text('☀'));
    await tester.pumpAndSettle();

    expect(display.isLight, isTrue);
    expect(find.text('☾'), findsOneWidget);
  });

  test('the two palettes disagree about everything they should', () {
    // Not an inversion: each colour is chosen for its own background. What
    // matters is that none of them is shared, since a colour that works on
    // near-black rarely works on near-white.
    const dark = OniPalette.dark;
    const light = OniPalette.light;

    expect(light.background, isNot(dark.background));
    expect(light.text, isNot(dark.text));
    expect(light.accent, isNot(dark.accent));
    for (final category in ItemCategory.values) {
      if (!dark.items.containsKey(category)) continue;
      expect(light.items[category], isNot(dark.items[category]),
          reason: '$category is the same colour in both');
    }
  });

  test('text stays readable against its own background', () {
    // The one property that matters and the one easiest to lose while picking
    // colours: body text against the page, in both.
    double luminance(Color c) => c.computeLuminance();
    double contrast(Color a, Color b) {
      final light = luminance(a) > luminance(b) ? a : b;
      final dark = luminance(a) > luminance(b) ? b : a;
      return (luminance(light) + 0.05) / (luminance(dark) + 0.05);
    }

    for (final palette in [OniPalette.dark, OniPalette.light]) {
      expect(contrast(palette.text, palette.background), greaterThan(7),
          reason: 'body text');
      expect(contrast(palette.textMuted, palette.background), greaterThan(3.5),
          reason: 'muted text');
      expect(contrast(palette.accent, palette.background), greaterThan(3),
          reason: 'the accent');
    }
  });

  test('the choice outlives the session', () async {
    final store = MemoryJsonStore();
    final first = DisplayController(store);
    await first.load();
    await first.setLight(light: true);

    final second = DisplayController(store);
    await second.load();

    expect(second.isLight, isTrue);
    expect(OniTheme.current, OniPalette.light);
  });
}
