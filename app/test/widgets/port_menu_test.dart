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
    bool Function(ProcessSpec)? offers,
  }) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline ?? loneElectrolyzer());
    await tester.pumpWidget(harness(
      GraphCanvas(
        key: canvasKey,
        controller: controller,
        rateDisplay: RateDisplay.perSecond,
        offers: offers ?? (_) => true,
        onToggleRates: () {},
      ),
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

  group('a class port', () {
    /// Reported: an Iron Ore supply, click its output, pick Metal Refinery,
    /// and nothing happened at all. The refinery asks for the class "metal
    /// ore" and the supply offers iron ore, so the menu offered it and the
    /// click quietly declined.
    Pipeline oreSupply() => (PipelineBuilder(testDatabase, name: 'ore')
          ..addSource('iron_ore', nodeId: 'ore', x: 200, y: 200))
        .build();

    test('takes a member of the class it asks for', () {
      final c = testController(pipeline: oreSupply());
      final ref = PortRef('ore', c.specOf(c.pipeline.nodeOrThrow('ore')).outputs.first.id);

      expect(c.candidatesFor(ref).map((s) => s.id), contains('metal_refinery'),
          reason: 'the menu offers it');
      final added = c.addNodeFor(ref, 'metal_refinery');

      expect(added, isNotNull, reason: 'so clicking it has to do something');
      expect(c.pipeline.edges, hasLength(1));
      expect(c.pipeline.edges.single.toNodeId, added);
      expect(c.pipeline.edges.single.toPortId, 'metal_ore');
      // And the wire it drew is one the solver is happy with: a class port
      // takes the member, and nothing has to be chosen first.
      expect(c.solution.issues.where((i) => i.isError), isEmpty);
    });

    test('and the wire runs the other way too', () {
      final c = testController(
          pipeline: (PipelineBuilder(testDatabase, name: 'refine')
                ..add('metal_refinery', nodeId: 'ref', x: 400, y: 200))
              .build());
      final added =
          c.addNodeFor(const PortRef('ref', 'metal_ore'), 'source:iron_ore');

      expect(added, isNotNull);
      expect(c.pipeline.edges.single.fromNodeId, added);
    });
  });

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
      // Plenty of things make water now, so narrow the list before picking.
      await tester.enterText(
        find.descendant(
          of: find.byType(PortMenu),
          matching: find.byType(EditableText),
        ),
        'sieve',
      );
      await tester.pump();
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

  group('what a port will take', () {
    testWidgets('a port asking for a class is offered the members',
        (tester) async {
      final controller = await pumpCanvas(
        tester,
        pipeline: (PipelineBuilder(testDatabase, name: 'smelting')
              ..add('metal_refinery', nodeId: 'refinery', x: 300, y: 200)
              ..pinCount('refinery', 1))
            .build(),
      );

      final names = controller
          .candidatesFor(const PortRef('refinery', 'metal_ore'))
          .map((s) => s.name)
          .toList();

      // An Iron Ore supply feeds a port that asks for Metal Ore; before the
      // classes were taught to this list, it offered nothing at all.
      expect(names, contains('Iron Ore supply'));
      expect(names, contains('Copper Ore supply'));
      expect(names, isNot(contains('Water supply')));
    });

    testWidgets('and once a metal is chosen, only that one', (tester) async {
      final controller = await pumpCanvas(
        tester,
        pipeline: (PipelineBuilder(testDatabase, name: 'smelting')
              ..add('metal_refinery', nodeId: 'refinery', x: 300, y: 200)
              ..pinCount('refinery', 1))
            .build(),
      );
      controller.setMaterial('refinery', 'metal_ore', 'copper_ore');
      await tester.pump();

      final names = controller
          .candidatesFor(const PortRef('refinery', 'metal_ore'))
          .map((s) => s.name)
          .toList();

      expect(names, contains('Copper Ore supply'));
      expect(names, isNot(contains('Iron Ore supply')));
    });
  });

  group('what the menu is allowed to offer', () {
    testWidgets('a pack switched off does not come back through the port menu',
        (tester) async {
      // The palette hides Aquatic content; clicking a port was a second door
      // into the same catalogue, and it was not locked.
      final controller = await pumpCanvas(
        tester,
        pipeline: (PipelineBuilder(testDatabase, name: 'sea')
              ..add('flue_coral', nodeId: 'coral', x: 300, y: 200)
              ..pinCount('coral', 1))
            .build(),
        offers: (spec) => !spec.tags.contains('aquatic'),
      );

      await tester.tapAt(screenPort(controller, const PortRef('coral', 'salt_water')));
      await tester.pump();

      expect(find.byType(PortMenu), findsOneWidget);
      expect(find.text('Desalinator (Salt Water)'), findsNothing);
      // The supply node is not pack content and is still the quickest answer.
      expect(find.textContaining('Salt Water supply'), findsWidgets);
    });

    testWidgets('with everything filtered out it says which', (tester) async {
      // An empty list has two meanings and they want different answers. This
      // one is "you switched a pack off", and saying so is the difference
      // between a dead end and a door — every item has a supply node, so the
      // *other* meaning is now rare enough to be worth distinguishing.
      final controller = await pumpCanvas(tester, offers: (_) => false);

      await tester.tapAt(screenPort(controller, const PortRef('elec', 'water')));
      await tester.pump();

      expect(find.byType(PortMenu), findsOneWidget);
      expect(find.textContaining('hidden by your pack filters'), findsOneWidget);
    });

    test('and no port in the whole database is a dead end', () {
      // The claim the message above rests on, checked rather than asserted:
      // every item has a generated supply and output, so every port has
      // something to offer. If that ever stops being true, the message needs
      // its old branch back.
      var checked = 0;
      for (final spec in testDatabase.processes) {
        final controller = testController(
          pipeline: (PipelineBuilder(testDatabase, name: 'one')
                ..add(spec.id, nodeId: 'n'))
              .build(),
        );
        for (final port in spec.ports) {
          checked++;
          expect(controller.candidatesFor(PortRef('n', port.id)), isNotEmpty,
              reason: '${spec.id}.${port.id} has nothing to offer');
        }
      }
      expect(checked, greaterThan(1000));
    });

    testWidgets('and a search that matches nothing says so, not the catalogue',
        (tester) async {
      // It used to say "Nothing here makes water", which is never true: every
      // item has a generated supply and output, so no port's list is empty of
      // its own accord. 1 415 of them were checked. What is empty is your
      // search, and that is what it says now.
      final controller = await pumpCanvas(tester);
      await tester.tapAt(screenPort(controller, const PortRef('elec', 'water')));
      await tester.pump();

      await tester.enterText(find.byType(EditableText).last, 'zzzz');
      await tester.pump();

      expect(find.textContaining('Nothing here matches "zzzz"'), findsOneWidget);
      expect(find.textContaining('makes water'), findsNothing);
    });

  });
}