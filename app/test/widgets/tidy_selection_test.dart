import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/auto_layout.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  /// Two builds on one canvas: an oxygen chain, and a ranch placed by hand
  /// somewhere the owner wants it left.
  Pipeline twoBuilds() => (PipelineBuilder(testDatabase, name: 'Two')
        ..addSource('water', x: 0, y: 0)
        ..add('electrolyzer', nodeId: 'elec', x: 900, y: 700)
        ..addSink('oxygen', x: 100, y: 1300)
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'sink_oxygen', 'oxygen')
        ..add('hatch', nodeId: 'hatches', x: 2400, y: 40)
        ..add('coal_generator', nodeId: 'gen', x: 2400, y: 400)
        ..connectItem('hatches', 'gen', 'coal')
        ..pinCount('elec', 1)
        ..pinCount('hatches', 6))
      .build();

  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: twoBuilds());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  group('tidying part of a canvas', () {
    test('only the chosen nodes move', () {
      final pipeline = twoBuilds();
      final positions = AutoLayout(
        pipeline: pipeline,
        database: testDatabase,
        only: const {'src_water', 'elec', 'sink_oxygen'},
      ).positions();

      expect(positions.keys, hasLength(3));
      expect(positions.containsKey('hatches'), isFalse);
    });

    test('the chosen nodes are still ordered by what feeds what', () {
      final positions = AutoLayout(
        pipeline: twoBuilds(),
        database: testDatabase,
        only: const {'src_water', 'elec', 'sink_oxygen'},
      ).positions();

      expect(positions['src_water']!.dx, lessThan(positions['elec']!.dx));
      expect(positions['elec']!.dx, lessThan(positions['sink_oxygen']!.dx));
    });

    testWidgets('Tidy leaves an unselected build where its owner put it',
        (tester) async {
      final controller = await pumpEditor(tester);
      controller.selectNodes(['src_water', 'elec', 'sink_oxygen']);
      await tester.pump();
      final ranch = controller.pipeline.nodeOrThrow('hatches');

      await tester.tap(find.text('Tidy'));
      await tester.pumpAndSettle();

      expect(controller.pipeline.nodeOrThrow('hatches').x, ranch.x);
      expect(controller.pipeline.nodeOrThrow('hatches').y, ranch.y);
      expect(controller.pipeline.nodeOrThrow('elec').x,
          isNot(900), reason: 'the selected build was arranged');
    });

    testWidgets('with nothing selected it still tidies everything',
        (tester) async {
      final controller = await pumpEditor(tester);
      final ranch = controller.pipeline.nodeOrThrow('hatches');

      await tester.tap(find.text('Tidy'));
      await tester.pumpAndSettle();

      expect(controller.pipeline.nodeOrThrow('hatches').x, isNot(ranch.x));
    });
  });

  group('framing part of a canvas', () {
    testWidgets('Fit frames the selection when there is one', (tester) async {
      final controller = await pumpEditor(tester);
      controller.selectNodes(['hatches', 'gen']);
      await tester.pump();

      await tester.tap(find.text('Fit'));
      await tester.pumpAndSettle();

      final state = tester.state<GraphCanvasState>(find.byType(GraphCanvas));
      final visible = state.visibleWorldRect;
      expect(visible.contains(const Offset(2400, 40)), isTrue);
      // The far-off oxygen chain is not what was asked about.
      expect(visible.contains(const Offset(0, 0)), isFalse);
    });

    testWidgets('with nothing selected it frames the lot', (tester) async {
      final controller = await pumpEditor(tester);
      controller.select(null);
      await tester.pump();

      await tester.tap(find.text('Fit'));
      await tester.pumpAndSettle();

      final state = tester.state<GraphCanvasState>(find.byType(GraphCanvas));
      expect(state.visibleWorldRect.contains(const Offset(0, 0)), isTrue);
      expect(state.visibleWorldRect.contains(const Offset(2400, 400)), isTrue);
    });
  });
}
