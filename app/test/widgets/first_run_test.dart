import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/display_controller.dart';
import 'package:oni_pipeline/state/library_controller.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

/// Somebody opening this for the first time.
///
/// Nothing has ever checked it end to end, and it is the one screen every
/// single person sees. Every store empty, every setting unset, no build —
/// which is also the state where a mistake in what a *missing* setting means
/// does its damage, and there was one of those this week.
void main() {
  /// The whole app, wired to stores with nothing in them.
  Future<({PipelineController pipeline, DisplayController display})> firstRun(
      WidgetTester tester) async {
    final display = DisplayController(MemoryJsonStore());
    await display.load();
    final library = LibraryController(
      bundled: testDatabase,
      store: MemoryJsonStore(),
    );
    await library.load();
    final controller = PipelineController(library.database);
    final workspace = WorkspaceController(
      store: MemoryJsonStore(),
      controller: controller,
      debounce: Duration.zero,
    );
    await workspace.load();
    addTearDown(workspace.dispose);

    await tester.pumpWidget(harness(listening(
      controller,
      (_) => EditorScreen(
        controller: controller,
        library: library,
        workspace: workspace,
        displaySettings: display,
      ),
    )));
    await tester.pumpAndSettle();
    return (pipeline: controller, display: display);
  }

  testWidgets('opens on an empty canvas and does not fall over',
      (tester) async {
    await useDesktopSurface(tester);
    final app = await firstRun(tester);
    expect(tester.takeException(), isNull);
    expect(app.pipeline.pipeline.nodes, isEmpty);
    expect(find.byType(EditorScreen), findsOneWidget);
  });

  testWidgets('with every pack on, including the newest', (tester) async {
    // A first run has said nothing about packs, so it should be shown
    // everything. This is the state the knownPacks fix is really about: a
    // saved setting that predates a pack looks the same as no setting at all
    // if nobody is careful.
    await useDesktopSurface(tester);
    final app = await firstRun(tester);
    for (final pack in kContentPacks.keys) {
      expect(app.display.packEnabled(pack), isTrue, reason: pack);
    }
  });

  testWidgets('and the catalogue can be searched from cold', (tester) async {
    // The list is long and built lazily, so what is on screen depends on
    // where you are in it. Searching is what a person does.
    await useDesktopSurface(tester);
    await firstRun(tester);
    await tester.enterText(paletteSearch(), 'electrolyzer');
    await tester.pumpAndSettle();
    expect(find.text('Electrolyzer'), findsOneWidget);
  });

  testWidgets('and a build made on a first run survives a restart',
      (tester) async {
    // The other half: the app is no use if what you draw is gone tomorrow.
    await useDesktopSurface(tester);
    final store = MemoryJsonStore();
    final first = PipelineController(testDatabase);
    final workspace = WorkspaceController(
      store: store,
      controller: first,
      debounce: Duration.zero,
    );
    await workspace.load();
    first.addNode('electrolyzer', Offset.zero);
    await workspace.adopt(first.pipeline);
    await workspace.saveNow();
    workspace.dispose();

    final second = PipelineController(testDatabase);
    final reopened = WorkspaceController(
      store: store,
      controller: second,
      debounce: Duration.zero,
    );
    await reopened.load();
    addTearDown(reopened.dispose);
    expect(reopened.saved, isNotEmpty, reason: 'it kept what was drawn');
  });
}
