
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/demo/demo_player.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';

import '../support/harness.dart';

/// Where a demo is offered, and where it is not.
void main() {
  late PipelineController controller;
  late WorkspaceController workspace;
  late DemoPlayer player;

  Future<void> pump(WidgetTester tester, {required Pipeline pipeline}) async {
    await useDesktopSurface(tester);
    controller = testController(pipeline: pipeline);
    workspace = await testWorkspace(controller);
    player = DemoPlayer(
      workspace: workspace,
      controller: controller,
    );
    addTearDown(player.dispose);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: workspace,
      displaySettings: testDisplay(),
      loadGuide: () async => '# Using it\n\nWords.',
      demoPlayer: player,
    )));
    await tester.pumpAndSettle();
  }

  Pipeline empty() =>
      Pipeline(id: 'blank', name: 'Blank', nodes: const [], edges: const []);

  testWidgets('an empty canvas offers to show you one', (tester) async {
    await pump(tester, pipeline: empty());

    expect(find.text('Watch: What a geyser feeds'), findsOneWidget);

    await tester.tap(find.text('Watch: What a geyser feeds'));
    await tester.pumpAndSettle();

    expect(player.isRunning, isTrue);
    // In a build of its own, so the blank canvas is still there to come back
    // to. Nothing has happened in it yet: a press does that.
    expect(controller.pipeline.id, isNot('blank'));
    expect(controller.pipeline.nodes, isEmpty);
    expect(player.run!.nextSays, contains('Water Geyser'));
  });

  testWidgets('and the guide offers it too, for a canvas that is not empty',
      (tester) async {
    await pump(tester, pipeline: testPipeline());
    expect(find.text('Watch: What a geyser feeds'), findsNothing,
        reason: 'there is no empty canvas to put it on');

    await tester.ensureVisible(find.text('Guide'));
    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch a demo'));
    await tester.pumpAndSettle();

    expect(player.isRunning, isTrue);
    // The guide got out of the way rather than sitting over the thing it just
    // offered to show you.
    expect(find.text('Watch a demo'), findsNothing);
  });

  testWidgets('and an app built without a player offers nothing at all',
      (tester) async {
    // The tests that are about templates should not have to know demos exist,
    // and neither should a screen embedded somewhere without one.
    await useDesktopSurface(tester);
    final plain = testController(pipeline: empty());
    await tester.pumpWidget(harness(EditorScreen(
      controller: plain,
      library: testLibrary(),
      workspace: await testWorkspace(plain),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('Watch'), findsNothing);
    expect(find.text('OR START FROM ONE OF THESE'), findsOneWidget);
  });
}
