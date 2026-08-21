import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/geometry.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/problems_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  final canvasKey = GlobalKey<GraphCanvasState>();

  /// One node near the origin and one a long way off, well outside any window.
  Pipeline spreadOut() => (PipelineBuilder(testDatabase, name: 'Spread')
        ..add('electrolyzer', nodeId: 'elec', x: 0, y: 0)
        ..add('coal_generator', nodeId: 'far', x: 6000, y: 4000)
        ..pinCount('elec', 1))
      .build();

  Future<PipelineController> pumpCanvas(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: spreadOut());
    await tester.pumpWidget(harness(GraphCanvas(
      key: canvasKey,
      controller: controller,
      rateDisplay: RateDisplay.perSecond,
    )));
    return controller;
  }

  bool isVisible(PipelineController c, String id) {
    final state = canvasKey.currentState!;
    final node = c.pipeline.nodeOrThrow(id);
    final size = NodeLayout.sizeOf(c.specOf(node));
    final topLeft = state.localFromWorld(Offset(node.x, node.y));
    final bottomRight =
        state.localFromWorld(Offset(node.x + size.width, node.y + size.height));
    const viewport = Rect.fromLTWH(0, 0, 1440, 900);
    return viewport.contains(topLeft) && viewport.contains(bottomRight);
  }

  testWidgets('selecting a node that is off screen brings it into view',
      (tester) async {
    final controller = await pumpCanvas(tester);
    expect(isVisible(controller, 'far'), isFalse, reason: 'it starts far away');

    controller.selectNode('far');
    await tester.pump();

    expect(isVisible(controller, 'far'), isTrue);
  });

  testWidgets('a node already in view is left where it is', (tester) async {
    final controller = await pumpCanvas(tester);
    final before = canvasKey.currentState!.offset;

    controller.selectNode('elec');
    await tester.pump();

    expect(canvasKey.currentState!.offset, before,
        reason: 'moving the view when nothing needed moving is disorienting');
  });

  testWidgets('the zoom is left alone', (tester) async {
    final controller = await pumpCanvas(tester);
    canvasKey.currentState!.zoomAtCentre(1.5);
    await tester.pump();

    controller.selectNode('far');
    await tester.pump();

    expect(canvasKey.currentState!.scale, closeTo(1.5, 1e-9));
    expect(isVisible(controller, 'far'), isTrue);
  });

  testWidgets('a marquee of several does not move the view', (tester) async {
    final controller = await pumpCanvas(tester);
    final before = canvasKey.currentState!.offset;

    controller.selectNodes(['elec', 'far']);
    await tester.pump();

    expect(canvasKey.currentState!.offset, before);
  });

  testWidgets('clicking the suggestion in the banner goes to the node',
      (tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: spreadOut());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));

    // The far generator is the thing with no scale, so it is the suggestion.
    expect(find.text('GIVE AN AMOUNT FOR'), findsOneWidget);
    final state = tester.state<GraphCanvasState>(find.byType(GraphCanvas));
    final before = state.offset;

    await tester.tap(find.descendant(
      of: find.byType(ProblemsBanner),
      matching: find.text('Coal Generator'),
    ));
    await tester.pump();

    expect(controller.selectedNode?.id, 'far');
    expect(state.offset, isNot(before), reason: 'the view went to find it');
  });
}
