import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// What the last edit did to the totals.
///
/// The app says when an edit *broke* a build. This is the other half of the
/// question everybody has been asking — "what did adding that do?" — for the
/// ordinary case where nothing broke at all.
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

  testWidgets('an edit that costs power says so', (tester) async {
    final controller = await pumpEditor(tester);
    expect(controller.sinceLastEdit, isNull,
        reason: 'nothing has been done to it yet');

    final before = controller.solution.netPowerWatts;
    controller.pin(const BuildingCountPin(nodeId: 'dupes', count: 30));
    await tester.pumpAndSettle();

    final effect = controller.sinceLastEdit;
    expect(effect, isNotNull);
    expect(effect!.changes.map((c) => c.label), contains('power'));
    final power = effect.changes.firstWhere((c) => c.label == 'power');
    expect(power.before, closeTo(before, 1e-6));
    expect(power.after, isNot(closeTo(before, 1e-6)));
  });

  testWidgets('and it is on the totals bar, named by the edit',
      (tester) async {
    // An edit that moves a figure: a node placed and never given an amount
    // changes nothing, and says nothing.
    final controller = await pumpEditor(tester);
    controller.pin(const BuildingCountPin(nodeId: 'dupes', count: 30));
    await tester.pumpAndSettle();

    expect(textContaining('SINCE THE AMOUNT ON THE DUPLICANT'),
        findsOneWidget);
    expect(textContaining('power'), findsWidgets);
  });

  testWidgets('and an edit that changes no total says nothing',
      (tester) async {
    // Moving a node is an edit and is not news. A line that appears after
    // every drag is a line nobody reads.
    final controller = await pumpEditor(tester);
    controller.moveNode('elec', const Offset(80, 80));
    await tester.pumpAndSettle();

    expect(controller.sinceLastEdit, isNull);
    expect(textContaining('SINCE '), findsNothing);
  });
}
