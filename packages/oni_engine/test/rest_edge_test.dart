import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// "The rest goes here", which could not be said at all.
///
/// An output node hung on a generator that also powers three buildings is
/// neither a consumer with a demand of its own — nothing says how much it
/// wants — nor a producer's fixed fraction, which takes the lot and starves
/// the buildings. It is the surplus, and how big that is depends on what the
/// others take. Reported three times over before it had a name.
void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  /// A generator powering a crusher, with somewhere for the spare to go.
  Pipeline spare(EdgeMode mode, {bool pinCrusher = true}) {
    final base = (PipelineBuilder(db, name: 'spare power')
          ..add('natural_gas_generator', nodeId: 'gen')
          ..addSource('natural_gas')
          ..add('rock_crusher_sand', nodeId: 'crusher')
          ..addSource('raw_mineral')
          ..addSink('sand')
          ..addSink('power')
          ..connectItem('src_natural_gas', 'gen', 'natural_gas')
          ..connectItem('src_raw_mineral', 'crusher', 'raw_mineral')
          ..connectItem('crusher', 'sink_sand', 'sand')
          ..connect('gen', 'power_out', 'crusher', 'power_in')
          ..pinCount('gen', 2))
        .build();
    final pinned = pinCrusher
        ? base.copyWith(
            pins: [...base.pins, const BuildingCountPin(nodeId: 'crusher', count: 1)])
        : base;
    return pinned.copyWith(edges: [
      ...pinned.edges,
      PipelineEdge(
        id: 'spare',
        fromNodeId: 'gen',
        fromPortId: 'power_out',
        toNodeId: 'sink_power',
        toPortId: 'in',
        mode: mode,
      ),
    ]);
  }

  test('a consumer-driven output is a loose end', () {
    // What the app did before: nothing says how much an output node wants.
    expect(solver.solve(spare(EdgeMode.pull, pinCrusher: false)).status,
        SolveStatus.underdetermined);
  });

  test('and a producer-driven one takes the lot', () {
    // The other thing that could be said, which starves the crusher.
    final issues = validatePipeline(spare(EdgeMode.push), db);
    expect(issues.map((i) => i.message).join(), contains('already spoken for'));
  });

  test('the rest is what anybody meant', () {
    final solution = solver.solve(spare(EdgeMode.rest));
    expect(solution.status, SolveStatus.solved);

    // Two generators make 1 600 W. The crusher takes 240 W of it, and what is
    // left is what the output node gets.
    final made = solution.nodes['gen']!.count * 800;
    final crusher = solution.edgeFlows['gen.power_out->crusher.power_in']!;
    expect(made, closeTo(1600, 1e-6));
    expect(crusher, closeTo(240, 1e-6));
    expect(solution.edgeFlows['spare'], closeTo(1600 - 240, 1e-6));
  });

  test('and it follows the others rather than being recomputed by hand', () {
    // The whole point: change what the neighbours take and the remainder
    // moves with it, which a share written down as 0.85 does not.
    final bigger = spare(EdgeMode.rest);
    final withTwo = bigger.copyWith(
      nodes: [
        ...bigger.nodes,
        const PipelineNode(id: 'crusher2', specId: 'rock_crusher_sand'),
      ],
      edges: [
        ...bigger.edges,
        const PipelineEdge(
          id: 'power2',
          fromNodeId: 'gen',
          fromPortId: 'power_out',
          toNodeId: 'crusher2',
          toPortId: 'power_in',
        ),
      ],
      // Its ore comes from outside the build, which is beside the point here.
      pins: [...bigger.pins, const BuildingCountPin(nodeId: 'crusher2', count: 1)],
    );
    final solution = solver.solve(withTwo);
    expect(solution.status, SolveStatus.solved);
    expect(solution.edgeFlows['spare'], closeTo(1600 - 480, 1e-6),
        reason: 'two crushers now, and the spare shrank by exactly one');
  });

  test('several lines saying "the rest" divide it equally', () {
    final one = spare(EdgeMode.rest);
    final two = one.copyWith(nodes: [
      ...one.nodes,
      const PipelineNode(id: 'sink_power2', specId: 'sink:power'),
    ], edges: [
      ...one.edges,
      const PipelineEdge(
        id: 'spare2',
        fromNodeId: 'gen',
        fromPortId: 'power_out',
        toNodeId: 'sink_power2',
        toPortId: 'in',
        mode: EdgeMode.rest,
      ),
    ]);
    final solution = solver.solve(two);
    expect(solution.status, SolveStatus.solved);
    expect(solution.edgeFlows['spare'], closeTo((1600 - 240) / 2, 1e-6));
    expect(solution.edgeFlows['spare2'], closeTo((1600 - 240) / 2, 1e-6));
  });

  test('and it survives being written down and read back', () {
    final there = spare(EdgeMode.rest);
    final back = PipelineShareCode.decode(PipelineShareCode.encode(there));
    expect(back.edges.firstWhere((e) => e.id == 'spare').mode, EdgeMode.rest);
    expect(solver.solve(back).edgeFlows['spare'],
        closeTo(solver.solve(there).edgeFlows['spare']!, 1e-9));
  });

  test('and says so when there is no rest to send', () {
    // "The rest" is only sensible while there is a rest. Two crushers wanting
    // 480 W off one generator making 400 leaves the remainder line carrying
    // 80 W backwards, which is a thing no wire does.
    final base = spare(EdgeMode.rest);
    final starved = base.copyWith(
      nodes: [
        ...base.nodes,
        const PipelineNode(id: 'crusher2', specId: 'rock_crusher_sand'),
      ],
      edges: [
        ...base.edges,
        const PipelineEdge(
          id: 'power2',
          fromNodeId: 'gen',
          fromPortId: 'power_out',
          toNodeId: 'crusher2',
          toPortId: 'power_in',
        ),
      ],
      pins: [
        const BuildingCountPin(nodeId: 'gen', count: 0.5),
        const BuildingCountPin(nodeId: 'crusher', count: 1),
        const BuildingCountPin(nodeId: 'crusher2', count: 1),
      ],
    );

    final solution = solver.solve(starved);
    final said = solution.issues.map((i) => i.message).join(' ');
    expect(said, contains('There is no rest to send'));
    expect(said, contains('80.00'));
    // And it points at the line as well as the port.
    final issue = solution.issues
        .firstWhere((i) => i.message.contains('There is no rest to send'));
    expect(issue.places.map((p) => p.edgeId), contains('spare'));
  });

  test('and the optimiser answers inside it, and leaves it alone', () {
    // Asking for the most power out of a build whose spare line says "the
    // rest" must not answer by writing a share over it: a share is today's
    // number frozen, and this line exists so that it is never stale.
    final pipeline = spare(EdgeMode.rest);
    final best = mostOf(pipeline, db, 'power');
    expect(best.isAnswer, isTrue);

    final answered = withShares(pipeline, db, best);
    final line = answered.edges.firstWhere((e) => e.id == 'spare');
    expect(line.mode, EdgeMode.rest);
    expect(line.share, isNull);

    // And the answer it wrote still solves to the same figures.
    final solution = solver.solve(answered);
    expect(solution.status, SolveStatus.solved);
    expect(solution.edgeFlows['spare'], closeTo(1600 - 240, 1e-6));
  });

  test('and it says what a remainder line does to the producer\'s size', () {
    // The one thing "the rest" costs: a generator used to be sized by what
    // drew from it, and once the surplus has somewhere to go it can be any
    // size at all. Both ends settle the other, and which one somebody knows
    // depends on what they are planning from.
    final full = spare(EdgeMode.rest);
    // The crusher keeps its amount; the generator loses its, which is the
    // shape somebody has when they wire the surplus up before sizing anything.
    final loose = full.copyWith(
      pins: [for (final pin in full.pins) if (pin.nodeId != 'gen') pin],
    );
    final solution = solver.solve(loose);
    expect(solution.status, SolveStatus.underdetermined);

    final said = solution.issues.map((i) => i.message).join(' ');
    expect(said, contains('carries the rest'));
    expect(said, contains('no longer sized by what draws from it'));
    expect(said, contains('Natural Gas Generator'));
    expect(said, contains('Power output'));
  });
}
