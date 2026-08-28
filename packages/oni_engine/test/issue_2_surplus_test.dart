import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Issue #2: "Generic Surplus / Remainder outputs for materials".
///
/// The scenario, in his words: three Oil Wells and eight Duplicants both set,
/// and the question is not "how many Duplicants can this support" but "given
/// what I have, what is left over". Wiring an ordinary Water output beside the
/// Electrolyzer made the output take half the sieve, which pushed the
/// Electrolyzer to 2.18 when eight Duplicants need 0.901 of one.
///
/// Every line of his specification for a Surplus output is what a line
/// carrying the rest already does, so this is that build, measured.
void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  /// A sieve whose water feeds an Electrolyzer for eight Duplicants, with
  /// somewhere for the spare to go.
  Pipeline sieve(EdgeMode spare) {
    final base = (PipelineBuilder(db, name: 'issue 2')
          ..add('water_sieve', nodeId: 'sieve')
          ..addSource('polluted_water')
          ..add('electrolyzer', nodeId: 'elec')
          ..add('duplicant', nodeId: 'dupes')
          ..addSink('hydrogen')
          ..addSink('water', nodeId: 'spare_water')
          ..connectItem('src_polluted_water', 'sieve', 'polluted_water')
          ..connectItem('elec', 'dupes', 'oxygen')
          ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
          ..pinCount('dupes', 8)
          ..pinCount('sieve', 1))
        .build();
    return base.copyWith(edges: [
      ...base.edges,
      // The Electrolyzer takes what it needs, which is what the Duplicants
      // breathing decides; the spare takes the rest.
      PipelineEdge(
        id: 'to_elec',
        fromNodeId: 'sieve',
        fromPortId: 'water',
        toNodeId: 'elec',
        toPortId: 'water',
        mode: spare == EdgeMode.push ? EdgeMode.push : EdgeMode.pull,
      ),
      PipelineEdge(
        id: 'to_spare',
        fromNodeId: 'sieve',
        fromPortId: 'water',
        toNodeId: 'spare_water',
        toPortId: 'in',
        mode: spare,
      ),
    ]);
  }

  test('an ordinary output takes half the sieve, which is the bug', () {
    // Two producer-driven lines with no shares divide the port equally, so the
    // Electrolyzer is sized by what it is handed rather than by what the
    // Duplicants breathe.
    final solution = solver.solve(sieve(EdgeMode.push));
    expect(solution.status, SolveStatus.inconsistent,
        reason: 'eight Duplicants and half a sieve disagree about the size of '
            'the Electrolyzer');
  });

  test('and a line carrying the rest measures it instead', () {
    final solution = solver.solve(sieve(EdgeMode.rest));
    expect(solution.status, SolveStatus.solved);

    // 8 × 100 g/s of oxygen, and an Electrolyzer makes 888.
    expect(solution.nodes['elec']!.count, closeTo(800 / 888, 1e-6));
    // Which drinks 1 kg/s each.
    final drunk = solution.edgeFlows['to_elec']!;
    expect(drunk, closeTo(1000 * 800 / 888, 1e-6));
    // And the spare is the sieve's 5 kg/s less that, measured rather than
    // chosen: it claims no share, sets no scale and splits nothing.
    expect(solution.edgeFlows['to_spare'], closeTo(5000 - drunk, 1e-6));

  });

  test('and a deficit is reported rather than rescaling the build', () {
    // His last ask: "if the result is negative, it could be reported as a
    // deficit rather than forcing the graph into a different scale."
    final hungry = sieve(EdgeMode.rest).copyWith(pins: const [
      BuildingCountPin(nodeId: 'dupes', count: 8),
      BuildingCountPin(nodeId: 'sieve', count: 0.1),
    ]);
    final said = solver.solve(hungry).issues.map((i) => i.message).join(' ');
    expect(said, contains('There is no rest to send'));
    expect(said, contains('backwards'));
  });

  test('and two set amounts in one build are kept, both of them', () {
    // The other half of the report: forcing two SET values worked better than
    // he expected. It is not a trick — a pin is per node, and nothing here
    // has ever insisted on only one.
    final solution = solver.solve(sieve(EdgeMode.rest));
    expect(solution.nodes['dupes']!.count, closeTo(8, 1e-9));
    expect(solution.nodes['sieve']!.count, closeTo(1, 1e-9));
  });
}
