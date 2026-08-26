import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/demo/demo_player.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';

import '../support/harness.dart';

/// The one offer, on the one visit where nobody knows there is anything to see.
void main() {
  late PipelineController controller;
  late WorkspaceController workspace;
  late DemoPlayer player;

  Future<void> pump(WidgetTester tester,
      {required bool firstVisit, bool withPlayer = true}) async {
    await useDesktopSurface(tester);
    controller = testController(pipeline: testPipeline());
    workspace = await testWorkspace(controller);
    player = DemoPlayer(
      workspace: workspace,
      controller: controller,
      schedule: (_, _) => Timer(Duration.zero, () {}),
    );
    addTearDown(player.dispose);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: workspace,
      displaySettings: testDisplay(),
      demoPlayer: withPlayer ? player : null,
      firstVisit: firstVisit,
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('a first visit is offered a look round', (tester) async {
    await pump(tester, firstVisit: true);

    expect(find.textContaining('First time here?'), findsOneWidget);
    expect(find.text('Show me'), findsOneWidget);
    // An offer, not an interruption: nothing has started.
    expect(player.isRunning, isFalse);
    expect(controller.pipeline.id, testPipeline().id);
  });

  testWidgets('and every visit after it is not', (tester) async {
    // There was a session to restore, so somebody has been here before.
    await pump(tester, firstVisit: false);

    expect(find.textContaining('First time here?'), findsNothing);
  });

  testWidgets('taking it plays the demo, and the offer is spent',
      (tester) async {
    await pump(tester, firstVisit: true);
    await tester.tap(find.text('Show me'));
    await tester.pumpAndSettle();

    expect(player.isRunning, isTrue);
    expect(find.textContaining('First time here?'), findsNothing);

    // And it does not come back when the demo is over.
    await player.leave();
    await tester.pumpAndSettle();
    expect(find.textContaining('First time here?'), findsNothing);
  });

  testWidgets('and waving it away is one button, for good', (tester) async {
    await pump(tester, firstVisit: true);
    await tester.tap(find.text('No thanks'));
    await tester.pumpAndSettle();

    expect(find.textContaining('First time here?'), findsNothing);
    expect(player.isRunning, isFalse);
  });

  testWidgets('an app with no player offers nothing, first visit or not',
      (tester) async {
    await pump(tester, firstVisit: true, withPlayer: false);

    expect(find.textContaining('First time here?'), findsNothing);
  });
}
