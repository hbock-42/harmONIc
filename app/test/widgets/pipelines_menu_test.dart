import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/canvas/node_widget.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/main.dart';
import 'package:oni_pipeline/panels/pipelines_menu.dart';
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

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.text('Pipelines'));
    await tester.pumpAndSettle();
  }

  testWidgets('the menu lists what is saved and marks the open one',
      (tester) async {
    await pumpEditor(tester);
    await openMenu(tester);

    expect(find.byType(PipelinesMenu), findsOneWidget);
    expect(find.text('Test build'), findsWidgets);
    // The top bar says "4 nodes" too, so look inside the menu.
    expect(
      find.descendant(
        of: find.byType(PipelinesMenu),
        matching: textContaining('4 nodes'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a new pipeline opens empty and the old one is still listed',
      (tester) async {
    await pumpEditor(tester);
    await openMenu(tester);
    await tester.tap(find.text('+ New'));
    await tester.pumpAndSettle();

    expect(find.byType(NodeWidget), findsNothing);
    expect(find.text('Nothing here yet'), findsOneWidget);

    await openMenu(tester);
    expect(find.text('Test build'), findsWidgets);
    expect(find.text('New pipeline'), findsWidgets);
  });

  testWidgets('reopening the first one brings its graph back', (tester) async {
    await pumpEditor(tester);
    final firstName = controller.pipeline.name;
    await openMenu(tester);
    await tester.tap(find.text('+ New'));
    await tester.pumpAndSettle();
    expect(find.byType(NodeWidget), findsNothing);

    await openMenu(tester);
    await tester.tap(find.descendant(
      of: find.byType(PipelinesMenu),
      matching: textLabel(firstName),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NodeWidget), findsNWidgets(4));
    expect(controller.pipeline.name, firstName);
  });

  testWidgets('renaming from the top bar sticks', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(OniField),
        matching: find.byType(EditableText),
      ).first,
      'Oxygen for the crew',
    );
    await tester.pumpAndSettle();

    expect(controller.pipeline.name, 'Oxygen for the crew');
    final saved = (store.data!['pipelines'] as List<dynamic>).first
        as Map<String, dynamic>;
    expect(saved['name'], 'Oxygen for the crew');
  });

  testWidgets('an edit on the canvas is on disk without pressing save',
      (tester) async {
    await pumpEditor(tester);
    controller.addNode('coal_generator', const Offset(40, 40));
    await tester.pumpAndSettle();

    final saved = (store.data!['pipelines'] as List<dynamic>).first
        as Map<String, dynamic>;
    expect((saved['nodes'] as List<dynamic>).length, 5);
  });

  testWidgets('the whole app reopens where it left off', (tester) async {
    await useDesktopSurface(tester);
    final shared = MemoryJsonStore();

    await tester.pumpWidget(OniPipelineApp(
      library: testLibrary(),
      pipelineStore: shared,
      initial: testPipeline(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(NodeWidget), findsNWidgets(4));

    // Close and start again against the same storage.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(OniPipelineApp(
      library: testLibrary(),
      pipelineStore: shared,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NodeWidget), findsNWidgets(4),
        reason: 'the saved build came back, not the starter');
    expect(find.text('Nothing here yet'), findsNothing);
  });
}
