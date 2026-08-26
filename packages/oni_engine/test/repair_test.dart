import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();

  /// The build that broke: drawn when a Starnacle published both its crop and
  /// its growth, and opened after those became two separate processes.
  Pipeline wiredToAPortThatMoved() => Pipeline(
        id: 'old',
        name: 'Reef',
        nodes: const [
          PipelineNode(id: 'plants', specId: 'starnacle', x: 0, y: 0),
          PipelineNode(id: 'beakons', specId: 'beakon_grazing', x: 400, y: 0),
        ],
        edges: const [
          PipelineEdge(
            id: 'e',
            fromNodeId: 'plants',
            fromPortId: 'starnacle_growth',
            toNodeId: 'beakons',
            toPortId: 'starnacle_growth',
          ),
        ],
        pins: const [BuildingCountPin(nodeId: 'beakons', count: 8)],
      );

  test('a good pipeline is left exactly alone', () {
    final fine = (PipelineBuilder(db, name: 'fine')
          ..addSource('water')
          ..add('electrolyzer', nodeId: 'elec')
          ..connectItem('src_water', 'elec', 'water')
          ..pinCount('elec', 1))
        .build();

    final repair = repairPipeline(fine, db);
    expect(repair.changed, isFalse);
    expect(repair.notes, isEmpty);
    expect(repair.pipeline.nodes, fine.nodes);
    expect(repair.pipeline.edges, fine.edges);
    expect(repair.pipeline.pins, fine.pins);

    // The one thing it does add is the recipe snapshot, so that next time the
    // build is opened there is something to compare the rates against.
    expect(repair.pipeline.recipeSnapshot.keys, contains('electrolyzer'));

    // And once it has one, nothing is touched at all.
    expect(identical(repairPipeline(repair.pipeline, db).pipeline,
        repair.pipeline), isTrue);
  });

  test('a corrected recipe is reported, not applied in silence', () {
    final saved = (PipelineBuilder(db, name: 'bathroom')
          ..add('deodorizer', nodeId: 'deo')
          ..pinCount('deo', 4))
        .build();

    // The Deodorizer's filtration medium was wrong for a long time: 5 g/s
    // where the game uses 133 g/s. A build saved against the old figure needs 27 times the
    // sand once it is opened again, and must say so.
    final stale = saved.copyWith(recipeSnapshot: {
      'deodorizer': {
        for (final port in db.processOrThrow('deodorizer').ports)
          port.id:
              port.itemId == 'filtration_medium' ? 5.0 : port.ratePerSecond,
      },
    });

    final repair = repairPipeline(stale, db);
    expect(repair.changed, isTrue);
    expect(repair.notes.single, contains('Filtration Medium'));
    expect(repair.notes.single, contains('not 5'));
    expect(repair.notes.single, contains('takes'));

    // Nothing about the build itself moved.
    expect(repair.pipeline.nodes, stale.nodes);
    expect(repair.pipeline.pins, stale.pins);
    // And it is only said once: the snapshot is brought up to date.
    expect(repairPipeline(repair.pipeline, db).notes, isEmpty);
  });

  group('a port that moved to another process', () {
    test('the node follows it rather than the wire being cut', () {
      final repair = repairPipeline(wiredToAPortThatMoved(), db);

      expect(repair.changed, isTrue);
      expect(repair.pipeline.nodeOrThrow('plants').specId, 'starnacle_grazed');
      expect(repair.pipeline.edges, hasLength(1),
          reason: 'the wiring survives');
      expect(repair.notes.single, contains('Starnacle'));
    });

    test('and the repaired build solves', () {
      final repaired = repairPipeline(wiredToAPortThatMoved(), db).pipeline;
      final solution = PipelineSolver(db).solve(repaired);

      expect(solution.status, SolveStatus.solved);
      // Eight Beakons at 12.5 % of a plant each: four Starnacles.
      expect(solution.nodes['plants']!.count, closeTo(4, 1e-4));
    });

    test('everything about the node is carried across', () {
      final original = wiredToAPortThatMoved();
      final moved = original.copyWith(
        nodes: [
          for (final n in original.nodes)
            if (n.id == 'plants')
              n.copyWith(x: 123, y: 456, outputScale: 0.75)
            else
              n,
        ],
      );
      final repaired = repairPipeline(moved, db).pipeline.nodeOrThrow('plants');

      expect(repaired.x, 123);
      expect(repaired.y, 456);
      expect(repaired.outputScale, 0.75);
    });
  });

  group('things that cannot be saved', () {
    test('a node naming a process that is gone is removed, and said so', () {
      final pipeline = Pipeline(
        id: 'stale',
        name: 'Stale',
        nodes: const [
          PipelineNode(id: 'ghost', specId: 'source:mealwood'),
          PipelineNode(id: 'elec', specId: 'electrolyzer'),
        ],
        edges: const [
          PipelineEdge(
            id: 'e',
            fromNodeId: 'ghost',
            fromPortId: 'out',
            toNodeId: 'elec',
            toPortId: 'water',
          ),
        ],
      );

      final repair = repairPipeline(pipeline, db);
      expect(repair.pipeline.node('ghost'), isNull);
      expect(repair.pipeline.node('elec'), isNotNull,
          reason: 'the rest of the build survives');
      expect(repair.pipeline.edges, isEmpty);
      expect(repair.notes.first, contains('source:mealwood'));
    });

    test('a pin on a port that is gone is dropped', () {
      final pipeline = Pipeline(
        id: 'pinned',
        name: 'Pinned',
        nodes: const [PipelineNode(id: 'plants', specId: 'starnacle')],
        pins: const [
          PortRatePin(
              nodeId: 'plants', portId: 'starnacle_growth', ratePerSecond: 1),
        ],
      );

      final repair = repairPipeline(pipeline, db);
      expect(repair.pipeline.pins, isEmpty);
      expect(repair.notes, isNotEmpty);
    });

    test('a wire with nowhere to move is cut, not left to crash', () {
      final pipeline = Pipeline(
        id: 'cut',
        name: 'Cut',
        nodes: const [
          PipelineNode(id: 'elec', specId: 'electrolyzer'),
          PipelineNode(id: 'gen', specId: 'coal_generator'),
        ],
        edges: const [
          PipelineEdge(
            id: 'e',
            fromNodeId: 'elec',
            fromPortId: 'nonsense',
            toNodeId: 'gen',
            toPortId: 'coal',
          ),
        ],
      );

      final repair = repairPipeline(pipeline, db);
      expect(repair.pipeline.edges, isEmpty);
      expect(repair.pipeline.nodes, hasLength(2), reason: 'the nodes stay');
    });
  });

  test('a repaired pipeline always validates', () {
    for (final broken in [wiredToAPortThatMoved()]) {
      final repaired = repairPipeline(broken, db).pipeline;
      expect(validatePipeline(repaired, db).where((i) => i.isError), isEmpty);
    }
  });
  test('a wire follows its port when the port is renamed', () {
    // A port's id is part of the saved format, and a recipe that gains a
    // choice gets its port renamed for it: the Electric Grill's
    // "sleet_wheat_grain" became "grain" the day megafrond grain became an
    // alternative to it. Every build already drawn was wired by the old name,
    // and used to lose the wire — along with every other wire on that node,
    // because a node that no longer fits was treated as a node with nothing
    // worth keeping.
    final saved = Pipeline(
      id: 'old',
      name: 'Canteen',
      nodes: const [
        PipelineNode(id: 'wheat', specId: 'sleet_wheat'),
        PipelineNode(id: 'grill', specId: 'electric_grill_frost_bun'),
      ],
      edges: const [
        PipelineEdge(
          id: 'e1',
          fromNodeId: 'wheat',
          fromPortId: 'sleet_wheat_grain',
          toNodeId: 'grill',
          // What it was called before the megafrond alternative arrived.
          toPortId: 'sleet_wheat_grain',
        ),
      ],
    );

    final repair = repairPipeline(saved, db);

    expect(repair.pipeline.edges, hasLength(1));
    expect(repair.pipeline.edges.single.toPortId, 'grain');
    expect(repair.notes.join(), contains('under a new name'));
  });

  test('and it is not moved when the guess would be a guess', () {
    // Two ports carrying the same thing in the same direction is a fork, and
    // picking one of them would be inventing a decision somebody else made.
    final spec = db.processOrThrow('electric_grill_souffle_pancakes');
    final grain = spec.inputs.where((p) => p.accepted.contains('megafrond_grain'));
    expect(grain, hasLength(1), reason: 'the premise of the rule above');
  });

}
