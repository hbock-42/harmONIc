import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/node_widget.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// The build does not move when the message above it does.
///
/// Reported while dragging a card over another one: the moment the banner said
/// a card was buried it grew, which pushed the canvas down, and the whole
/// build jumped — then jumped back when the message went. The message
/// appearing is fine. The build moving under your hand is not.
void main() {
  Future<PipelineController> open(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: testPipeline());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();
    return controller;
  }

  /// Where a card that has not moved in the build is drawn on the screen.
  Offset whereTheDupesAre(WidgetTester tester) => tester.getTopLeft(
        find.byWidgetPredicate(
          (w) => w is NodeWidget && w.node.id == 'dupes',
        ),
      );

  testWidgets('a message appearing above it does not shift the canvas',
      (tester) async {
    final controller = await open(tester);
    final before = whereTheDupesAre(tester);
    expect(controller.hiddenCards, isEmpty);

    // Bury one card under another, which is what makes the banner grow.
    final elec = controller.pipeline.nodeOrThrow('elec');
    controller.moveNode('src_water', Offset(elec.x, elec.y));
    await tester.pumpAndSettle();

    expect(controller.hiddenCards, isNotEmpty,
        reason: 'the banner has something new to say');
    expect(textContaining('hidden under'), findsOneWidget);
    expect(whereTheDupesAre(tester), before,
        reason: 'and the build did not move while it said it');
  });

  testWidgets('and does not shift it back when the message goes',
      (tester) async {
    final controller = await open(tester);
    final elec = controller.pipeline.nodeOrThrow('elec');
    controller.moveNode('src_water', Offset(elec.x, elec.y));
    await tester.pumpAndSettle();

    final withMessage = whereTheDupesAre(tester);
    controller.reveal('src_water');
    await tester.pumpAndSettle();

    expect(textContaining('hidden under'), findsNothing);
    expect(whereTheDupesAre(tester), withMessage);
  });
}
