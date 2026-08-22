import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  Future<PipelineController> pumpEditor(
    WidgetTester tester,
    Pipeline pipeline,
  ) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  /// An Electrolyzer on its own: water unfed, oxygen and hydrogen unclaimed.
  Pipeline lonely() => (PipelineBuilder(testDatabase, name: 'Lonely')
        ..add('electrolyzer', nodeId: 'elec', x: 0, y: 0)
        ..pinCount('elec', 2))
      .build();

  testWidgets('the button says how many there are to draw', (tester) async {
    await pumpEditor(tester, lonely());

    // Water in, oxygen and hydrogen out. Power is not counted: it arrives by
    // wire and the totals already say so.
    expect(find.text('Draw 3 supplies'), findsOneWidget);
  });

  testWidgets('pressing it closes the build off', (tester) async {
    final controller = await pumpEditor(tester, lonely());

    await tester.ensureVisible(find.text('Draw 3 supplies'));
    await tester.pump();
    await tester.tap(find.text('Draw 3 supplies'));
    await tester.pumpAndSettle();

    expect(controller.openPorts, isEmpty);
    expect(controller.pipeline.nodes, hasLength(4));
    expect(controller.solution.status, SolveStatus.solved);
    // And the button goes away, having nothing left to offer.
    expect(textContaining('Draw'), findsNothing);
  });

  testWidgets('it is one undo, not one per node', (tester) async {
    final controller = await pumpEditor(tester, lonely());

    await tester.ensureVisible(find.text('Draw 3 supplies'));
    await tester.pump();
    await tester.tap(find.text('Draw 3 supplies'));
    await tester.pumpAndSettle();
    expect(controller.pipeline.nodes, hasLength(4));

    controller.undo();
    await tester.pump();

    // All three at once: closing a build off is one decision, and pressing ⌘Z
    // three times to change your mind about it would make it a decision
    // nobody takes.
    expect(controller.pipeline.nodes, hasLength(1));
  });

  testWidgets('a build that is already closed off does not offer it',
      (tester) async {
    final closed = (PipelineBuilder(testDatabase, name: 'Closed')
          ..addSource('water', x: 0, y: 0)
          ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
          ..addSink('oxygen', x: 680, y: 0)
          ..addSink('hydrogen', x: 680, y: 200)
          ..connectItem('src_water', 'elec', 'water')
          ..connectItem('elec', 'sink_oxygen', 'oxygen')
          ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
          ..pinCount('elec', 1))
        .build();
    await pumpEditor(tester, closed);

    expect(textContaining('Draw'), findsNothing);
  });

  testWidgets('and the sample build has two of its own', (tester) async {
    // Worth pinning: the build this app ships with is not closed either. Its
    // crew has to eat and its carbon dioxide has to go somewhere, and neither
    // was drawn — which is exactly the sort of thing this button is for.
    await pumpEditor(tester, testPipeline());
    expect(find.text('Draw 2 supplies'), findsOneWidget);
  });

  testWidgets('a vented port is a decision, not an omission', (tester) async {
    final controller = await pumpEditor(tester, lonely());
    controller.setPortVenting('elec', 'hydrogen', venting: true);
    await tester.pump();

    // Venting says "this goes nowhere on purpose", so it is not something
    // waiting to be drawn.
    expect(find.text('Draw 2 supplies'), findsOneWidget);
  });
}
