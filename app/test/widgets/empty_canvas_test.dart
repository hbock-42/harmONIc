import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/node_widget.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';

import '../support/harness.dart';

/// The one screen somebody sees before they know what the app can do.
void main() {
  late PipelineController controller;
  late WorkspaceController workspace;

  Future<void> pumpEmpty(WidgetTester tester) async {
    await useDesktopSurface(tester);
    controller = testController(pipeline: Pipeline(id: 'blank', name: 'Blank'));
    workspace = await testWorkspace(controller);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: workspace,
      displaySettings: testDisplay(),
    )));
  }

  testWidgets('a blank canvas offers the worked builds', (tester) async {
    await pumpEmpty(tester);

    expect(textContaining('Nothing here yet'), findsOneWidget);
    // All four of them, by name, rather than two clicks away in a menu.
    for (final template in pipelineTemplates) {
      expect(find.text(template.name), findsOneWidget, reason: template.name);
    }
  });

  testWidgets('and pressing one opens it', (tester) async {
    await pumpEmpty(tester);
    final template = pipelineTemplates.first;

    await tester.tap(find.text(template.name));
    await tester.pumpAndSettle();

    // A canvas with something on it, and the empty state gone.
    expect(controller.pipeline.nodes, isNotEmpty);
    expect(controller.pipeline.name, template.name);
    expect(find.byType(NodeWidget), findsWidgets);
    expect(textContaining('Nothing here yet'), findsNothing);
  });

  testWidgets('and it is a build of its own, not a scribble on this one',
      (tester) async {
    await pumpEmpty(tester);
    await tester.tap(find.text(pipelineTemplates.first.name));
    await tester.pumpAndSettle();

    // The blank one it replaced is still in the menu: starting from an
    // example must not throw away what somebody had open.
    expect(workspace.saved.map((p) => p.name), contains('Blank'));
  });
}
