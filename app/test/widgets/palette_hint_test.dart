import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/panels/palette_panel.dart';

import '../support/harness.dart';

/// The palette says what a thing is for.
///
/// The first thing anybody asked about this app: "I'm unsure how to make use
/// of Arbor Tree vs Arbor Tree (grazed)". The answer was already written on
/// the recipe and the list showed only the name.
void main() {
  test('a row says what the recipe says about itself, in one sentence', () {
    final grazed = testDatabase.processOrThrow('arbor_tree_grazed');

    expect(paletteHint(grazed),
        'The same plant, left for a critter to graze instead of harvested.');
  });

  test('and a supply says nothing, having hundreds of identical twins', () {
    // "Whatever brings Water into this build" on all 214 of them is furniture.
    // Their names already say what they are.
    final supply = testDatabase.processOrThrow(sourceSpecId('water'));

    expect(supply.description, isNotNull);
    expect(paletteHint(supply), isNull);
  });

  test('and a recipe with nothing written about it says nothing', () {
    final bare = ProcessSpec(
      id: 'bare',
      name: 'Bare',
      kind: ProcessKind.building,
      ports: const [],
    );

    expect(paletteHint(bare), isNull);
  });

  testWidgets('and it is on the row, under the name', (tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));

    // Search rather than scroll: the palette is seven hundred rows long.
    await tester.enterText(
      find.descendant(
        of: find.byType(PalettePanel),
        matching: find.byType(OniField),
      ),
      'arbor tree (grazed)',
    );
    await tester.pumpAndSettle();

    expect(
      textContaining('left for a critter to graze'),
      findsOneWidget,
      reason: 'the answer to the question, where the question is asked',
    );
  });
}
