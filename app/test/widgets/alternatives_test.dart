import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(
      pipeline: (PipelineBuilder(testDatabase, name: 'Smokehouse')
            ..addSource('peat', x: 0, y: 0)
            ..add('smoker_brisket', nodeId: 'smoker', x: 340, y: 0)
            ..pinCount('smoker', 1))
          .build(),
    );
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  testWidgets('a port that takes either offers the choice', (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('smoker'));
    await tester.pump();

    // The inspector is a list and this sits below the fold on a node with as
    // much to say as a Smoker.
    final spec = testDatabase.processOrThrow('smoker_brisket');
    expect(choosablePorts(testDatabase, spec).map((p) => p.itemId),
        contains('wood'));
    await tester.scrollUntilVisible(find.text('TAKES'), 120,
        scrollable: find
            .descendant(
                of: find.byType(InspectorPanel),
                matching: find.byType(Scrollable))
            .first);
    await tester.pump();
    expect(find.text('TAKES'), findsOneWidget);
    expect(find.text('Any'), findsOneWidget);
    expect(find.text('Peat'), findsWidgets);
    // "Wood" is itself a class, so its members are what you actually pick from.
    expect(find.text('Lumber'), findsWidgets);
  });

  testWidgets('and a peat supply wires into it either way', (tester) async {
    final controller = await pumpEditor(tester);
    final smoker = testDatabase.processOrThrow('smoker_brisket');
    final fuel = smoker.inputs.firstWhere((p) => p.itemId != 'tough_meat');

    // Unset: peat is accepted.
    expect(
        controller.canConnect(
            const PortRef('src_peat', 'out'), PortRef('smoker', fuel.id)),
        isTrue);

    // Set to peat: still accepted.
    controller.setMaterial('smoker', fuel.id, 'peat');
    await tester.pump();
    expect(
        controller.canConnect(
            const PortRef('src_peat', 'out'), PortRef('smoker', fuel.id)),
        isTrue);

    // Set to lumber: peat is not lumber, and the app says so rather than
    // quietly accepting it.
    controller.setMaterial('smoker', fuel.id, 'lumber');
    await tester.pump();
    expect(
        controller.canConnect(
            const PortRef('src_peat', 'out'), PortRef('smoker', fuel.id)),
        isFalse);
  });

  testWidgets('the port menu offers both fuels', (tester) async {
    final controller = await pumpEditor(tester);
    final smoker = testDatabase.processOrThrow('smoker_brisket');
    final fuel = smoker.inputs.firstWhere((p) => p.itemId != 'tough_meat');

    final offered = controller
        .candidatesFor(PortRef('smoker', fuel.id))
        .map((s) => s.id)
        .toList();
    expect(offered, contains('source:peat'));
    expect(offered, contains('source:lumber'));
  });
}
