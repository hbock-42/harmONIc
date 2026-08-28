import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// The edit that broke it, named at the moment it breaks.
///
/// Every report has been phrased this way — "adding Oakshell Molt drained the
/// Tublia", "linking Cuddle Pip's dirt back zeroes a bunch of stuff" — and the
/// app made people prove what they already knew. It knows too: the undo stack
/// holds the build that was working a moment ago.
void main() {
  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('a wire that breaks a working build is named', (tester) async {
    final controller = await pumpEditor(tester);
    expect(controller.solution.status, SolveStatus.solved);
    expect(controller.broke, isNull);

    // A second Electrolyzer, pinned, pushing oxygen into the same Duplicants:
    // now two ends both insist on a size and they disagree.
    final second = controller.addNode('electrolyzer', Offset.zero);
    expect(controller.broke, isNull,
        reason: 'a build being drawn is underdetermined half the time, and '
            'being told off for every node placed is nagging');
    controller.pin(BuildingCountPin(nodeId: second, count: 5));
    controller.connect(
        PortRef(second, 'oxygen'), const PortRef('dupes', 'oxygen'));
    controller.setEdgeMode(
        controller.pipeline.edges.last.id, EdgeMode.push);
    await tester.pump();

    expect(controller.solution.status, isNot(SolveStatus.solved));
    expect(controller.broke, contains('drawing the line from the Electrolyzer'));
    expect(textContaining('is what broke this'), findsOneWidget);
  });

  testWidgets('and undoing it puts the build and the message back',
      (tester) async {
    final controller = await pumpEditor(tester);
    final second = controller.addNode('electrolyzer', Offset.zero);
    controller.pin(BuildingCountPin(nodeId: second, count: 5));
    controller.connect(
        PortRef(second, 'oxygen'), const PortRef('dupes', 'oxygen'));
    controller.setEdgeMode(
        controller.pipeline.edges.last.id, EdgeMode.push);
    await tester.pump();
    expect(find.text('Undo that   ⌘Z'), findsOneWidget);

    // One press puts the last edit back; the message goes when the build is
    // whole again, which for this one takes undoing the wire itself.
    await tester.tap(find.text('Undo that   ⌘Z'));
    await tester.pumpAndSettle();
    while (controller.solution.status != SolveStatus.solved &&
        controller.canUndo) {
      controller.undo();
    }
    await tester.pumpAndSettle();

    expect(controller.solution.status, SolveStatus.solved);
    expect(textContaining('is what broke this'), findsNothing);
  });

  testWidgets('and a build that was already broken says nothing',
      (tester) async {
    // Only the edit that *turned* it: somebody halfway through drawing a build
    // is not being told off for every wire.
    final controller = await pumpEditor(tester)..clearAllPins();
    await tester.pump();
    expect(controller.solution.status, isNot(SolveStatus.solved));

    controller.addNode('electrolyzer', Offset.zero);
    await tester.pump();
    expect(controller.broke, isNull);
  });
}
