import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/geometry.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  final canvasKey = GlobalKey<GraphCanvasState>();

  Future<PipelineController> pumpCanvas(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(
      GraphCanvas(
        key: canvasKey,
        controller: controller,
        rateDisplay: RateDisplay.perSecond,
        onToggleRates: () {},
      ),
    ));
    return controller;
  }

  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  group('selecting', () {
    test('a plain click replaces the selection', () {
      final c = testController()
        ..selectNode('elec')
        ..selectNode('dupes');
      expect(c.selectedNodeIds, {'dupes'});
    });

    test('an additive click adds, and clicking again removes', () {
      final c = testController()
        ..selectNode('elec')
        ..selectNode('dupes', additive: true);
      expect(c.selectedNodeIds, {'elec', 'dupes'});

      c.selectNode('elec', additive: true);
      expect(c.selectedNodeIds, {'dupes'});
    });

    test('selecting an edge clears the nodes', () {
      final c = testController()..selectNodes(['elec', 'dupes']);
      c.select(EdgeSelection(c.pipeline.edges.first.id));
      expect(c.selectedNodeIds, isEmpty);
      expect(c.selectedEdge, isNotNull);
    });

    test('the single-selection view still works for one node', () {
      final c = testController()..selectNode('elec');
      expect(c.selection, isA<NodeSelection>());
      expect(c.selectedNode?.id, 'elec');

      c.selectNode('dupes', additive: true);
      expect(c.selectedNode, isNull, reason: 'two nodes is not one node');
    });
  });

  group('moving a group', () {
    test('dragging one selected node moves them all', () {
      final c = testController()..selectNodes(['elec', 'dupes']);
      final before = {
        for (final id in ['elec', 'dupes', 'src_water'])
          id: c.pipeline.nodeOrThrow(id).x,
      };

      c.moveSelectionBy(const Offset(80, 0));

      // Snapping means "moved by about 80", not exactly.
      expect(c.pipeline.nodeOrThrow('elec').x,
          closeTo(before['elec']! + 80, NodeLayout.gridSize));
      expect(c.pipeline.nodeOrThrow('dupes').x,
          closeTo(before['dupes']! + 80, NodeLayout.gridSize));
      expect(c.pipeline.nodeOrThrow('src_water').x, before['src_water'],
          reason: 'an unselected node stays put');
    });

    test('a group move snaps to the grid', () {
      final c = testController()..selectNodes(['elec']);
      c.moveSelectionBy(const Offset(13, 7));
      final node = c.pipeline.nodeOrThrow('elec');
      expect(node.x % NodeLayout.gridSize, 0);
      expect(node.y % NodeLayout.gridSize, 0);
    });
  });

  group('deleting a group', () {
    test('takes the nodes, their edges and their pins', () {
      final c = testController()..selectNodes(['elec', 'dupes']);
      c.deleteSelection();

      expect(c.pipeline.node('elec'), isNull);
      expect(c.pipeline.node('dupes'), isNull);
      expect(c.pipeline.node('src_water'), isNotNull);
      expect(c.pipeline.edges, isEmpty, reason: 'every edge touched one of them');
      expect(c.pipeline.pins, isEmpty, reason: 'the pin was on the dupes');
      expect(c.selectedNodeIds, isEmpty);
    });

    test('is one undo step', () {
      final c = testController()..selectNodes(['elec', 'dupes']);
      c.deleteSelection();
      c.undo();
      expect(c.pipeline.nodes, hasLength(4));
    });
  });

  group('on the canvas', () {
    testWidgets('shift-dragging empty space rubber-bands a selection',
        (tester) async {
      final controller = await pumpCanvas(tester);
      final state = canvasKey.currentState!;

      // A band from above-left of the graph to below-right of the Electrolyzer.
      final from = state.localFromWorld(const Offset(-40, 40));
      final to = state.localFromWorld(const Offset(560, 260));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final gesture = await tester.startGesture(from);
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(controller.selectedNodeIds, containsAll(<String>['src_water', 'elec']));
      expect(controller.selectedNodeIds, isNot(contains('dupes')));
    });

    testWidgets('a plain drag on empty space still pans', (tester) async {
      final controller = await pumpCanvas(tester);
      final before = canvasKey.currentState!.offset;

      await tester.dragFrom(const Offset(1200, 700), const Offset(-60, 40));
      await tester.pump();

      expect(canvasKey.currentState!.offset.dx, lessThan(before.dx));
      expect(controller.selectedNodeIds, isEmpty);
    });

    testWidgets('dragging a node in a group carries the rest', (tester) async {
      final controller = await pumpCanvas(tester);
      controller.selectNodes(['elec', 'dupes']);
      await tester.pump();
      final before = controller.pipeline.nodeOrThrow('dupes').x;

      // Diagonal on purpose: a pure-axis `drag` offset synthesises a pointer
      // stream that no pan recogniser accepts, which is a quirk of the test
      // harness rather than of the canvas.
      await tester.drag(find.text('Electrolyzer'), const Offset(80, 24));
      await tester.pump();

      expect(controller.pipeline.nodeOrThrow('dupes').x, greaterThan(before),
          reason: 'the unclicked member came along');
    });

    testWidgets('dragging an unselected node selects just that one',
        (tester) async {
      final controller = await pumpCanvas(tester);
      controller.selectNodes(['dupes']);
      await tester.pump();

      await tester.drag(find.text('Electrolyzer'), const Offset(80, 24));
      await tester.pump();

      expect(controller.selectedNodeIds, {'elec'});
    });
  });

  group('the inspector', () {
    testWidgets('summarises a group instead of showing one node',
        (tester) async {
      final controller = await pumpEditor(tester);
      controller.selectNodes(['elec', 'dupes']);
      await tester.pump();

      expect(find.text('2 nodes selected'), findsOneWidget);
      expect(find.text('I HAVE THIS MANY'), findsNothing);
      expect(textContaining('Delete 2 nodes'), findsOneWidget);
    });

    testWidgets('deleting from the panel removes the group', (tester) async {
      final controller = await pumpEditor(tester);
      controller.selectNodes(['elec', 'dupes']);
      await tester.pump();

      await tester.tap(textContaining('Delete 2 nodes'));
      await tester.pump();

      expect(controller.pipeline.nodes, hasLength(2));
    });
  });
}
