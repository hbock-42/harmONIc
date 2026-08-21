import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  group('PipelineController', () {
    test('solves on construction', () {
      final c = testController();
      expect(c.solution.status, SolveStatus.solved);
      // 10 dupes breathe 1000 g/s, which pulls 1000/888 Electrolyzers.
      expect(c.solution.nodes['elec']!.count, closeTo(1000 / 888, 1e-9));
    });

    test('re-solves after every edit', () {
      final c = testController()..pin(const BuildingCountPin(nodeId: 'dupes', count: 20));
      expect(c.solution.nodes['elec']!.count, closeTo(2000 / 888, 1e-9));
    });

    test('notifies listeners on change', () {
      final c = testController();
      var notifications = 0;
      c.addListener(() => notifications++);
      c.addNode('coal_generator', const Offset(10, 10));
      expect(notifications, greaterThan(0));
    });

    test('adding a node snaps to the grid and selects it', () {
      final c = testController();
      final id = c.addNode('coal_generator', const Offset(103, 207));
      final node = c.pipeline.nodeOrThrow(id);
      expect(node.x % 8, 0);
      expect(node.y % 8, 0);
      expect(c.selection, isA<NodeSelection>());
    });

    group('connecting', () {
      test('refuses a mismatched item', () {
        final c = testController();
        expect(
          c.canConnect(
            const PortRef('elec', 'oxygen'),
            const PortRef('h2out', 'in'),
          ),
          isFalse,
        );
      });

      test('refuses output→output and self-links', () {
        final c = testController();
        expect(
          c.canConnect(const PortRef('elec', 'oxygen'),
              const PortRef('src_water', 'out')),
          isFalse,
        );
        expect(
          c.canConnect(const PortRef('elec', 'oxygen'),
              const PortRef('elec', 'water')),
          isFalse,
        );
      });

      test('refuses a duplicate link', () {
        final c = testController();
        expect(
          c.canConnect(const PortRef('elec', 'hydrogen'),
              const PortRef('h2out', 'in')),
          isFalse,
          reason: 'that link already exists',
        );
      });

      test('accepts a legal link and re-solves', () {
        final c = testController();
        final id = c.addNode('hydrogen_generator', const Offset(900, 400));
        // Rewire the hydrogen into a generator instead of the vent.
        c
          ..select(EdgeSelection(c.pipeline.edges
              .firstWhere((e) => e.toNodeId == 'h2out')
              .id))
          ..deleteSelection();
        c.connect(const PortRef('elec', 'hydrogen'), PortRef(id, 'hydrogen'));

        expect(c.pipeline.edges.any((e) => e.toNodeId == id), isTrue);
        expect(c.solution.nodes[id]!.count, greaterThan(0));
      });
    });

    test('deleting a node takes its edges and pin with it', () {
      final c = testController()
        ..select(const NodeSelection('elec'))
        ..deleteSelection();

      expect(c.pipeline.node('elec'), isNull);
      expect(c.pipeline.edges.where((e) =>
          e.fromNodeId == 'elec' || e.toNodeId == 'elec'), isEmpty);
      expect(c.selection, isNull);
    });

    test('deleting a pinned node removes the pin too', () {
      final c = testController()
        ..select(const NodeSelection('dupes'))
        ..deleteSelection();
      expect(c.pipeline.pins, isEmpty);
    });

    group('undo', () {
      test('restores the previous graph and solution', () {
        final c = testController();
        final before = c.solution.nodes['elec']!.count;
        c.pin(const BuildingCountPin(nodeId: 'dupes', count: 40));
        expect(c.solution.nodes['elec']!.count, isNot(closeTo(before, 1e-9)));

        c.undo();
        expect(c.solution.nodes['elec']!.count, closeTo(before, 1e-9));
        expect(c.canRedo, isTrue);
      });

      test('a whole drag is one step', () {
        final c = testController()..beginNodeDrag();
        for (var i = 0; i < 10; i++) {
          c.moveNode('elec', Offset(300 + i * 8, 100));
        }
        c.undo();
        expect(c.pipeline.nodeOrThrow('elec').x, 300);
        expect(c.canUndo, isFalse, reason: 'ten frames, one undo step');
      });

      test('redo replays it', () {
        final c = testController()
          ..pin(const BuildingCountPin(nodeId: 'dupes', count: 40))
          ..undo()
          ..redo();
        expect(c.solution.nodes['elec']!.count, closeTo(40 * 100 / 888, 1e-9));
      });
    });

    group('two builds sharing a canvas', () {
      /// The reported problem: an oxygen chain and a coal ranch on one page,
      /// where giving one an amount wiped the other's.
      PipelineController twoBuilds() {
        final pipeline = (PipelineBuilder(testDatabase, name: 'Two builds')
              ..addSource('water')
              ..add('electrolyzer', nodeId: 'elec')
              ..addSink('oxygen')
              ..addSink('hydrogen')
              ..connectItem('src_water', 'elec', 'water')
              ..connectItem('elec', 'sink_oxygen', 'oxygen')
              ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
              ..add('hatch', nodeId: 'hatches')
              ..add('coal_generator', nodeId: 'gen')
              ..connectItem('hatches', 'gen', 'coal'))
            .build();
        return PipelineController(testDatabase, initial: pipeline);
      }

      test('each keeps its own amount', () {
        final c = twoBuilds()
          ..pin(const BuildingCountPin(nodeId: 'elec', count: 3))
          ..pin(const BuildingCountPin(nodeId: 'hatches', count: 12));

        expect(c.solution.status, SolveStatus.solved);
        expect(c.solution.nodes['elec']!.count, closeTo(3, 1e-9));
        expect(c.solution.nodes['hatches']!.count, closeTo(12, 1e-9));
      });

      test('changing one does not disturb the other', () {
        final c = twoBuilds()
          ..pin(const BuildingCountPin(nodeId: 'hatches', count: 12))
          ..pin(const BuildingCountPin(nodeId: 'elec', count: 3))
          ..pin(const BuildingCountPin(nodeId: 'elec', count: 7));

        expect(c.pipeline.pins, hasLength(2));
        expect(c.solution.nodes['hatches']!.count, closeTo(12, 1e-9));
        expect(c.solution.nodes['elec']!.count, closeTo(7, 1e-9));
      });

      test('clearing one leaves the other set', () {
        final c = twoBuilds()
          ..pin(const BuildingCountPin(nodeId: 'elec', count: 3))
          ..pin(const BuildingCountPin(nodeId: 'hatches', count: 12))
          ..clearPin('elec');

        expect(c.pipeline.pins.single.nodeId, 'hatches');
        expect(c.solution.status, SolveStatus.underdetermined,
            reason: 'the oxygen build now has no scale, and says so');
        expect(c.solution.nodes['hatches']!.count, closeTo(12, 1e-9));
      });
    });

    test('pinning replaces the previous pin rather than stacking', () {
      final c = testController()
        ..pin(const BuildingCountPin(nodeId: 'elec', count: 3));
      expect(c.pipeline.pins, hasLength(1));
      expect(c.pinFor('dupes'), isNull);
      expect(c.solution.status, SolveStatus.solved);
    });

    test('clearing the pin leaves the graph underdetermined, not broken', () {
      final c = testController()..clearAllPins();
      expect(c.solution.status, SolveStatus.underdetermined);
      expect(c.solution.isUsable, isTrue);
    });

    test('switching an edge to push changes the answer', () {
      final c = testController();
      final edgeId =
          c.pipeline.edges.firstWhere((e) => e.toNodeId == 'dupes').id;
      c.setEdgeMode(edgeId, EdgeMode.push);
      // Pushing means the dupes take a fixed share of the oxygen instead of
      // sizing the Electrolyzer, so the pin now drives the other direction.
      expect(c.pipeline.edge(edgeId)!.mode, EdgeMode.push);
      expect(c.solution.isUsable, isTrue);
    });
  });
}
