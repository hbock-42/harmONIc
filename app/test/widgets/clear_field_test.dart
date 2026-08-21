import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/palette_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  Finder paletteSearch() => find.descendant(
        of: find.byType(PalettePanel),
        matching: find.byType(OniField),
      );

  testWidgets('an empty search offers nothing to clear', (tester) async {
    await pumpEditor(tester);

    expect(
        find.descendant(
            of: find.byType(PalettePanel), matching: find.byKey(clearFieldKey)),
        findsNothing);
  });

  testWidgets('typing offers a cross, and it empties the field',
      (tester) async {
    await pumpEditor(tester);

    await tester.enterText(paletteSearch(), 'oxyg');
    await tester.pump();
    // Scoped to the palette: the canvas has an Electrolyzer card on it too.
    Finder inPalette(String label) => find.descendant(
        of: find.byType(PalettePanel), matching: textLabel(label));
    // Duplicant sits in the first group of the unfiltered list and matches
    // nothing in "oxyg", so it is a good witness for the filter.
    expect(inPalette('Duplicant'), findsNothing,
        reason: 'the list is filtered to the search');
    expect(inPalette('Oxygen Diffuser'), findsWidgets);

    final cross = find.descendant(
        of: find.byType(PalettePanel), matching: find.byKey(clearFieldKey));
    expect(cross, findsOneWidget);

    await tester.tap(cross);
    await tester.pump();

    // The field is empty, the cross has gone with it, and the whole list is
    // back — which is the thing you wanted, not just an empty box.
    expect(tester.widget<OniField>(paletteSearch()).controller.text, '');
    expect(cross, findsNothing);
    expect(inPalette('Duplicant'), findsWidgets);
  });
}
