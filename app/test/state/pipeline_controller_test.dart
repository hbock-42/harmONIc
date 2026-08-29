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

    test('a wire onto a divided port joins the division', () {
      // Reported: dropping an output node on a port whose producer-driven
      // lines already divide all of it refused the whole build, because a
      // consumer-driven line there has nothing to take. Adding a fourth line
      // to a three-way split means dividing once more.
      final c = testController();
      final oxygen = c.pipeline.edges
          .firstWhere((e) => e.fromPortId == 'oxygen');
      c.setEdgeMode(oxygen.id, EdgeMode.push);
      expect(portIsFullyDivided(c.pipeline, PortRef(oxygen.fromNodeId, 'oxygen')),
          isTrue, reason: 'one producer-driven line with no share takes it all');

      final sink = c.addNode('sink:oxygen', Offset.zero);
      c.connect(PortRef(oxygen.fromNodeId, 'oxygen'), PortRef(sink, 'in'));

      expect(
        c.solution.issues
            .where((i) => i.severity == IssueSeverity.error)
            .map((i) => i.message)
            .join(' '),
        isNot(contains('already spoken for')),
      );
    });

    test('an output on a port that already feeds something takes the rest',
        () {
      // The surplus, which could not be said at all before: not a consumer
      // with a demand of its own (a loose end) and not the producer's whole
      // output (which starves everything else on the port).
      final c = testController();
      final out = c.addNode('sink:oxygen', Offset.zero);
      c.connect(const PortRef('elec', 'oxygen'), PortRef(out, 'in'));

      final line = c.pipeline.edges.firstWhere((e) => e.toNodeId == out);
      expect(line.mode, EdgeMode.rest);
      expect(line.share, isNull);
      expect(c.notice, contains('whatever is left'));
      // The Duplicants keep the line they had.
      expect(
        c.pipeline.edges
            .firstWhere((e) => e.toNodeId == 'dupes')
            .mode,
        EdgeMode.pull,
      );
    });

    test('and a second producer into one output node joins the first', () {
      // The other shape: an output node is a bucket, so two consumer-driven
      // lines into one read their shares as shares of each other and are held
      // to the same amount for ever after.
      final c = testController();
      final out = c.addNode('sink:hydrogen', Offset.zero);
      final second = c.addNode('electrolyzer', Offset.zero);
      c.connect(PortRef(second, 'hydrogen'), PortRef(out, 'in'));
      expect(c.pipeline.edges.firstWhere((e) => e.toNodeId == out).mode,
          EdgeMode.push,
          reason: 'a bucket takes what it is given, from the first line on');

      final third = c.addNode('electrolyzer', Offset.zero);
      c.connect(PortRef(third, 'hydrogen'), PortRef(out, 'in'));

      expect(
        c.pipeline.edges
            .where((e) => e.toNodeId == out)
            .every((e) => e.mode == EdgeMode.push),
        isTrue,
      );
      // No notice any more, and that is the improvement: it existed to own up
      // to changing a line the reader had not asked about, and now there is
      // no change to own up to.
      expect(c.notice, isNull);
    });

    test('but a line the reader set to the consumer is still owned up to', () {
      // The notice has not gone, only the case that no longer needs it. Set a
      // line to the consumer by hand, add a second, and the group still has
      // to move together — which is a change worth being told about.
      final c = testController();
      final out = c.addNode('sink:hydrogen', Offset.zero);
      final first = c.addNode('electrolyzer', Offset.zero);
      c.connect(PortRef(first, 'hydrogen'), PortRef(out, 'in'));
      final line = c.pipeline.edges.firstWhere((e) => e.toNodeId == out);
      c.setEdgeMode(line.id, EdgeMode.pull);

      final second = c.addNode('electrolyzer', Offset.zero);
      c.connect(PortRef(second, 'hydrogen'), PortRef(out, 'in'));
      expect(c.notice, contains('output node has no size of its own'));
    });

    test('and an output can still be the thing that sizes a build', () {
      // Producer-driven does not mean the output cannot lead: asking for a
      // rate out of it still settles what has to go in, which is the ordinary
      // way somebody says how big they want the thing.
      final c = testController();
      final out = c.addNode('sink:hydrogen', Offset.zero);
      final maker = c.addNode('electrolyzer', Offset.zero);
      c.connect(PortRef(maker, 'hydrogen'), PortRef(out, 'in'));
      c.clearAllPins();
      c.pin(PortRatePin(nodeId: out, portId: 'in', ratePerSecond: 224));
      expect(c.solution.status, isNot(SolveStatus.invalid));
      expect(c.solution.nodes[maker]!.count, greaterThan(0));
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

      test('dragging a card does not re-solve the build', () {
        // Position is a fact about the drawing, not about the arithmetic:
        // nothing in the solver reads a node's x or y. Re-solving on every
        // drag frame cost 9.9 ms on a reported 41-node build, out of the
        // 16.7 ms a frame has, to arrive back at the answer already on
        // screen. Object identity is the proof: a solve always returns a new
        // one, so the same instance means no solve happened.
        final c = testController();
        final before = c.solution;
        c.beginNodeDrag();
        for (var i = 0; i < 10; i++) {
          c.dragSelectionBy(Offset(i * 8.0, 0));
        }
        c.moveNode('elec', const Offset(500, 500));
        c.moveSelectionBy(const Offset(8, 8));
        c.applyLayout({'elec': const Offset(64, 64)});
        expect(identical(c.solution, before), isTrue,
            reason: 'moving cards about cannot change any figure');
      });

      test('but an edit still does', () {
        final c = testController();
        final before = c.solution;
        c.pin(const BuildingCountPin(nodeId: 'dupes', count: 40));
        expect(identical(c.solution, before), isFalse);
      });

      test('auto-layout is still one undo step', () {
        final c = testController();
        final was = c.pipeline.nodeOrThrow('elec').x;
        c.applyLayout({'elec': const Offset(640, 640)});
        expect(c.pipeline.nodeOrThrow('elec').x, 640);
        c.undo();
        expect(c.pipeline.nodeOrThrow('elec').x, was);
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
