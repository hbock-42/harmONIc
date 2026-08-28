import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Saying that a card is where nobody can see it.
///
/// A build whose arithmetic is perfect can still be missing half of itself
/// from the screen, so this is the one thing on the banner the solver has no
/// opinion about.
void main() {
  Future<PipelineController> pump(
      WidgetTester tester, Pipeline pipeline) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();
    return controller;
  }

  Pipeline buried() {
    final base = testPipeline();
    final elec = base.nodeOrThrow('elec');
    return base.copyWith(nodes: [
      for (final n in base.nodes)
        if (n.id == 'src_water') n.copyWith(x: elec.x, y: elec.y) else n,
    ]);
  }

  testWidgets('a build that adds up and hides nothing says nothing',
      (tester) async {
    await pump(tester, testPipeline());
    expect(textContaining('hidden'), findsNothing);
  });

  testWidgets('a buried card is named, along with what is on top of it',
      (tester) async {
    await pump(tester, buried());
    expect(textContaining('completely hidden under'), findsOneWidget);
  });

  testWidgets('and one press digs it out', (tester) async {
    final controller = await pump(tester, buried());
    final was = controller.pipeline.nodeOrThrow('src_water').y;

    await tester.tap(find.byKey(const ValueKey('reveal:src_water')));
    await tester.pumpAndSettle();

    expect(controller.pipeline.nodeOrThrow('src_water').y, greaterThan(was));
    expect(controller.hiddenCards, isEmpty);
    expect(textContaining('hidden'), findsNothing,
        reason: 'and the banner goes with it');
  });

  testWidgets('the card on top can be selected from the message',
      (tester) async {
    final controller = await pump(tester, buried());
    await tester.tap(find.byKey(const ValueKey('show-under:elec')));
    await tester.pumpAndSettle();
    expect(controller.selectedNodeIds, contains('elec'));
  });
}
