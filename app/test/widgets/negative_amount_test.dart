import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Typing a minus into an amount.
void main() {
  testWidgets('the app says which number is the problem', (tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));

    controller.select(const NodeSelection('elec'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(amountFieldKey), '-5');
    await tester.pumpAndSettle();

    // Named where it was typed, and in words about the amount rather than
    // about the edge shares, which is what the solver used to blame.
    expect(controller.solution.status, SolveStatus.invalid);
    expect(textContaining('below nothing'), findsWidgets);
    expect(textContaining('edge shares'), findsNothing);
  });
}
