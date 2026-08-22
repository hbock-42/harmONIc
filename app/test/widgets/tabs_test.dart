import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

void main() {
  late PipelineController controller;
  late WorkspaceController workspace;
  late MemoryJsonStore store;

  Future<void> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    store = MemoryJsonStore();
    controller = testController();
    workspace = await testWorkspace(controller, store);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: workspace,
      displaySettings: testDisplay(),
    )));
  }

  testWidgets('one build shows no tabs, because a single tab is a label',
      (tester) async {
    await pumpEditor(tester);
    expect(workspace.openTabs, hasLength(1));
    expect(find.text('Test build'), findsWidgets);
    // No strip: the name is already in the top bar.
    expect(workspace.openTabs.length < 2, isTrue);
  });

  testWidgets('a second build gives both a tab, and clicking switches',
      (tester) async {
    await pumpEditor(tester);
    final first = workspace.currentId!;
    await workspace.createNew(name: 'Second');
    await tester.pumpAndSettle();

    expect(workspace.openTabs.map((t) => t.name),
        containsAll(['Test build', 'Second']));
    expect(workspace.currentId, isNot(first));

    await tester.tap(find.text('Test build').first);
    await tester.pumpAndSettle();
    expect(workspace.currentId, first);
  });

  testWidgets('closing a tab puts the build away, it does not delete it',
      (tester) async {
    await pumpEditor(tester);
    await workspace.createNew(name: 'Second');
    await tester.pumpAndSettle();
    final second = workspace.currentId!;

    await workspace.closeTab(second);
    await tester.pumpAndSettle();

    // Gone from the tabs, still in the menu, and the neighbour is open.
    expect(workspace.openTabs.map((t) => t.id), isNot(contains(second)));
    expect(workspace.saved.map((t) => t.id), contains(second));
    expect(workspace.currentId, isNot(second));
  });

  testWidgets('and the open ones come back after a restart', (tester) async {
    await pumpEditor(tester);
    await workspace.createNew(name: 'Second');
    await workspace.createNew(name: 'Third');
    await tester.pumpAndSettle();
    expect(workspace.openTabs, hasLength(3));

    final reopened = WorkspaceController(
      store: store,
      controller: PipelineController(testDatabase),
      debounce: Duration.zero,
    );
    addTearDown(reopened.dispose);
    await reopened.load();

    expect(reopened.openTabs.map((t) => t.name),
        containsAll(['Test build', 'Second', 'Third']));
  });
}
