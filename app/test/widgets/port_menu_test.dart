import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/geometry.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/canvas/port_menu.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  final canvasKey = GlobalKey<GraphCanvasState>();

  /// A lone Electrolyzer: every port is unconnected, which is exactly the state
  /// this feature exists for.
  Pipeline loneElectrolyzer() =>
      (PipelineBuilder(testDatabase, name: 'lonely')
            ..add('electrolyzer', nodeId: 'elec', x: 300, y: 200)
            ..pinCount('elec', 2))
          .build();

  Future<PipelineController> pumpCanvas(
    WidgetTester tester, {
    Pipeline? pipeline,
  }) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline ?? loneElectrolyzer());
    await tester.pumpWidget(harness(
      GraphCanvas(key: canvasKey, controller: controller),
    ));
    return controller;
  }

  Offset screenPort(PipelineController c, PortRef ref) {
    final node = c.pipeline.nodeOrThrow(ref.nodeId);
    return canvasKey.currentState!
        .localFromWorld(NodeLayout.worldPortOffset(node, c.specOf(node), ref.portId));
  }

  Future<PipelineController> tapPort(WidgetTester tester, PortRef ref) async {
    final controller = await pumpCanvas(tester);
    await tester.tapAt(screenPort(controller, ref));
    await tester.pump();
    return controller;
  }

  group('candidates', () {
    test('an input port offers producers of that item', () {
      final c = testController(pipeline: loneElectrolyzer());
      final names =
          c.candidatesFor(const PortRef('elec', 'water')).map((s) => s.name);

      expect(names, contains('Water supply'));
      expect(names, contains('Water Sieve'));
      expect(names, isNot(contains('Coal Generator')),
          reason: 'a coal generator makes no water');
    });

    test('an output port offers consumers of that item', () {
      final c = testController(pipeline: loneElectrolyzer());
      final names =
          c.candidatesFor(const PortRef('elec', 'hydrogen')).map((s) => s.name);

      expect(names, contains('Hydrogen Generator'));
      expect(names, contains('Hydrogen output'));
      expect(names, isNot(contains('Water Sieve')));
    });

    test('boundary nodes come first', () {
      final c = testController(pipeline: loneElectrolyzer());
      final first = c.candidatesFor(const PortRef('elec', 'water')).first;
      expect(first.kind, ProcessKind.source);
    });

    test('a node is never offered as its own neighbour', () {
      final c = testController(pipeline: loneElectrolyzer());
      expect(
        c.candidatesFor(const PortRef('elec', 'water')).map((s) => s.id),
        isNot(contains('electrolyzer')),
      );
    });
  });

  group('placement', () {
    test('a producer lands to the left, wired into the port', () {
      final c = testController(pipeline: loneElectrolyzer());
      final id = c.addNodeFor(const PortRef('elec', 'water'), 'water_sieve')!;

      final added = c.pipeline.nodeOrThrow(id);
      expect(added.x, lessThan(300), reason: 'producers sit upstream');

      final edge = c.pipeline.edges.single;
      expect(edge.fromNodeId, id);
      expect(edge.toNodeId, 'elec');
      expect(edge.toPortId, 'water');
    });

    test('a consumer lands to the right, wired out of the port', () {
      final c = testController(pipeline: loneElectrolyzer());
      final id =
          c.addNodeFor(const PortRef('elec', 'hydrogen'), 'hydrogen_generator')!;

      expect(c.pipeline.nodeOrThrow(id).x, greaterThan(300));
      final edge = c.pipeline.edges.single;
      expect(edge.fromNodeId, 'elec');
      expect(edge.fromPortId, 'hydrogen');
      expect(edge.toNodeId, id);
    });

    test('the ports line up so the wire runs flat', () {
      final c = testController(pipeline: loneElectrolyzer());
      final id = c.addNodeFor(const PortRef('elec', 'water'), 'water_sieve')!;

      final anchor = c.pipeline.nodeOrThrow('elec');
      final added = c.pipeline.nodeOrThrow(id);
      final anchorPort = NodeLayout.worldPortOffset(
          anchor, c.specOf(anchor), 'water');
      final addedPort = NodeLayout.worldPortOffset(
          added, c.specOf(added), 'water');

      expect((anchorPort.dy - addedPort.dy).abs(), lessThanOrEqualTo(
          NodeLayout.gridSize));
    });

    test('a second node does not land on top of the first', () {
      final c = testController(pipeline: loneElectrolyzer());
      final a = c.addNodeFor(const PortRef('elec', 'water'), 'water_sieve')!;
      final b = c.addNodeFor(const PortRef('elec', 'water'), 'desalinator_brine')!;

      final rectA = Offset(c.pipeline.nodeOrThrow(a).x,
              c.pipeline.nodeOrThrow(a).y) &
          NodeLayout.sizeOf(c.specOf(c.pipeline.nodeOrThrow(a)));
      final rectB = Offset(c.pipeline.nodeOrThrow(b).x,
              c.pipeline.nodeOrThrow(b).y) &
          NodeLayout.sizeOf(c.specOf(c.pipeline.nodeOrThrow(b)));
      expect(rectA.overlaps(rectB), isFalse);
    });

    test('adding through a port is one undo step', () {
      final c = testController(pipeline: loneElectrolyzer());
      c.addNodeFor(const PortRef('elec', 'water'), 'water_sieve');
      c.undo();

      expect(c.pipeline.nodes, hasLength(1));
      expect(c.pipeline.edges, isEmpty);
    });

    test('the new node feeds the graph for real', () {
      final c = testController(pipeline: loneElectrolyzer());
      c.addNodeFor(const PortRef('elec', 'water'), 'source:water');

      // Two Electrolyzers drink 2000 g/s, and the supply now covers it.
      expect(c.solution.status, SolveStatus.solved);
      expect(c.solution.externalInputs['water'], isNull);
      expect(c.solution.nodes.values
          .firstWhere((n) => n.kind == ProcessKind.source).count,
          closeTo(2000, 1e-6));
    });
  });

  group('the menu', () {
    testWidgets('clicking a port opens it', (tester) async {
      await tapPort(tester, const PortRef('elec', 'water'));
      expect(find.byType(PortMenu), findsOneWidget);
      expect(textContaining('What supplies Water?'), findsOneWidget);
    });

    testWidgets('an output port asks the other question', (tester) async {
      await tapPort(tester, const PortRef('elec', 'oxygen'));
      expect(textContaining('Where does Oxygen go?'), findsOneWidget);
    });

    testWidgets('picking an entry places and wires it', (tester) async {
      final controller = await tapPort(tester, const PortRef('elec', 'water'));
      await tester.tap(find.descendant(
        of: find.byType(PortMenu),
        matching: textLabel('Water Sieve'),
      ));
      await tester.pump();

      expect(find.byType(PortMenu), findsNothing);
      expect(controller.pipeline.nodes, hasLength(2));
      expect(controller.pipeline.edges, hasLength(1));
      expect(controller.selection, isA<NodeSelection>());
    });

    testWidgets('the menu searches', (tester) async {
      await tapPort(tester, const PortRef('elec', 'water'));
      await tester.enterText(
        find.descendant(of: find.byType(PortMenu), matching: find.byType(EditableText)),
        'sieve',
      );
      await tester.pump();

      expect(
        find.descendant(
            of: find.byType(PortMenu), matching: textLabel('Water Sieve')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: find.byType(PortMenu), matching: textLabel('Water supply')),
        findsNothing,
      );
    });

    testWidgets('clicking away dismisses it', (tester) async {
      await tapPort(tester, const PortRef('elec', 'water'));
      expect(find.byType(PortMenu), findsOneWidget);

      await tester.tapAt(const Offset(1300, 800));
      await tester.pump();
      expect(find.byType(PortMenu), findsNothing);
    });

    testWidgets('dropping a wire on empty space opens it too', (tester) async {
      final controller = await pumpCanvas(tester);
      final from = screenPort(controller, const PortRef('elec', 'hydrogen'));

      final gesture = await tester.startGesture(from);
      await gesture.moveTo(const Offset(1150, 640));
      await gesture.up();
      await tester.pump();

      expect(find.byType(PortMenu), findsOneWidget);
      expect(textContaining('Where does Hydrogen go?'), findsOneWidget);
    });
  });
}
