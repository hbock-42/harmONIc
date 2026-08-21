import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  /// Two builds sharing one canvas: an oxygen chain and a coal ranch, with no
  /// wire between them.
  Pipeline twoBuilds() => (PipelineBuilder(db, name: 'Two builds')
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

  group('telling one build from another', () {
    test('the wired-together nodes are one group', () {
      final pipeline = twoBuilds();
      expect(componentOf(pipeline, 'elec'),
          {'src_water', 'elec', 'sink_oxygen', 'sink_hydrogen'});
      expect(componentOf(pipeline, 'hatches'), {'hatches', 'gen'});
    });

    test('following a wire backwards counts too', () {
      // The oxygen sink is downstream of everything, and still in the group.
      expect(componentOf(twoBuilds(), 'sink_oxygen'), contains('src_water'));
    });

    test('every group is found, largest first', () {
      final groups = connectedComponents(twoBuilds());
      expect(groups, hasLength(2));
      expect(groups.first, hasLength(4));
      expect(groups.last, hasLength(2));
    });

    test('a lone node is its own group', () {
      final pipeline = (PipelineBuilder(db, name: 'lonely')
            ..add('electrolyzer', nodeId: 'elec'))
          .build();
      expect(componentOf(pipeline, 'elec'), {'elec'});
    });
  });

  group('an amount belongs to its own build', () {
    test('setting one leaves the other alone', () {
      final pipeline = twoBuilds()
          .withPinInComponent(const BuildingCountPin(nodeId: 'elec', count: 2))
          .withPinInComponent(
              const BuildingCountPin(nodeId: 'hatches', count: 9));

      expect(pipeline.pins, hasLength(2));
      final solution = solver.solve(pipeline);
      expect(solution.status, SolveStatus.solved);
      expect(solution.nodes['elec']!.count, closeTo(2, 1e-9));
      expect(solution.nodes['hatches']!.count, closeTo(9, 1e-9));
    });

    test('setting it twice on the same build replaces, never stacks', () {
      final pipeline = twoBuilds()
          .withPinInComponent(const BuildingCountPin(nodeId: 'hatches', count: 9))
          .withPinInComponent(const BuildingCountPin(nodeId: 'elec', count: 2))
          .withPinInComponent(
              const BuildingCountPin(nodeId: 'src_water', count: 5000));

      // Both of those are in the oxygen build, so only the newer survives —
      // and the ranch keeps the amount it was given.
      expect(pipeline.pins, hasLength(2));
      expect(pipeline.pins.map((p) => p.nodeId), containsAll(['src_water', 'hatches']));
      expect(solver.solve(pipeline).status, SolveStatus.solved);
    });

    test('clearing one build does not clear the other', () {
      final pipeline = twoBuilds()
          .withPinInComponent(const BuildingCountPin(nodeId: 'elec', count: 2))
          .withPinInComponent(
              const BuildingCountPin(nodeId: 'hatches', count: 9))
          .withoutPinInComponent('elec');

      expect(pipeline.pins, hasLength(1));
      expect(pipeline.pins.single.nodeId, 'hatches');
    });

    test('wiring two builds together makes their amounts fight, as it should',
        () {
      // Once they share a supply they are one build, and two scales for one
      // build is a contradiction the solver is right to report.
      final joined = twoBuilds()
          .withPinInComponent(const BuildingCountPin(nodeId: 'elec', count: 2))
          .withPinInComponent(
              const BuildingCountPin(nodeId: 'hatches', count: 9));
      final wired = joined.copyWith(edges: [
        ...joined.edges,
        const PipelineEdge(
          id: 'join',
          fromNodeId: 'gen',
          fromPortId: 'power_out',
          toNodeId: 'elec',
          toPortId: 'power_in',
        ),
      ]);

      expect(componentOf(wired, 'elec'), contains('hatches'));
      expect(solver.solve(wired).status, SolveStatus.inconsistent);
    });
  });

  group('totals for one build', () {
    /// Two builds sharing a page: a SPOM that pays for itself, and a Metal
    /// Refinery that very much does not.
    Pipeline both() => (PipelineBuilder(db, name: 'two builds')
          ..addSource('water')
          ..add('electrolyzer', nodeId: 'elec')
          ..add('hydrogen_generator', nodeId: 'hgen')
          ..connectItem('src_water', 'elec', 'water')
          ..connectItem('elec', 'hgen', 'hydrogen')
          ..pinCount('elec', 4)
          ..addSource('iron_ore')
          ..add('metal_refinery', nodeId: 'refinery')
          ..connectItem('src_iron_ore', 'refinery', 'iron_ore')
          ..pinCount('refinery', 1))
        .build();

    test('the whole canvas adds up to something nobody can build', () {
      final solution = PipelineSolver(db).solve(both());
      expect(solution.status, SolveStatus.solved);

      // Four Electrolyzers draw 480 W and their generators make 3 584; the
      // refinery draws 1 200. The canvas nets out positive, which tells you
      // nothing about either build.
      expect(solution.netPowerWatts, closeTo(3584 - 480 - 1200, 1e-6));
    });

    test('and each build on its own adds up to something you can act on', () {
      final pipeline = both();
      final solution = PipelineSolver(db).solve(pipeline);

      final spom = solution.scopedTo(componentOf(pipeline, 'elec'));
      final smelting = solution.scopedTo(componentOf(pipeline, 'refinery'));

      expect(spom.netPowerWatts, closeTo(3584 - 480, 1e-6));
      expect(smelting.netPowerWatts, closeTo(-1200, 1e-6));
      // Neither knows anything about the other's materials.
      expect(spom.itemBalances.containsKey('iron_ore'), isFalse);
      expect(smelting.itemBalances.containsKey('hydrogen'), isFalse);
      // And the two halves still make the whole.
      expect(spom.netPowerWatts + smelting.netPowerWatts,
          closeTo(solution.netPowerWatts, 1e-6));
    });
  });
}