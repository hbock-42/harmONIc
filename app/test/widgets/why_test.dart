import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Why a number is the number it is, where somebody is looking at the number.
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

  testWidgets('the node you set says you set it', (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('dupes'));
    await tester.pumpAndSettle();

    expect(textContaining('You set this one'), findsOneWidget);
  });

  testWidgets('and the one that follows says what from', (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('elec'));
    await tester.pumpAndSettle();

    // Not a restatement of the number: the port that settled it and the two
    // figures that did.
    expect(textContaining('It is settled by'), findsOneWidget);
    expect(textContaining('oxygen'), findsWidgets);
  });

  testWidgets('and a loose end says it is loose', (tester) async {
    final controller = await pumpEditor(tester)..clearAllPins();
    await tester.pump();
    controller.select(NodeSelection(controller.solution.freeNodeIds.first));
    await tester.pumpAndSettle();

    expect(textContaining('Nothing settles this yet'), findsOneWidget);
  });
}
