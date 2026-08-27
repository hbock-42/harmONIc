import 'dart:io';

import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Three reports from one afternoon on the same build, all about being told
/// the wrong thing rather than about the arithmetic.
void main() {
  final db = loadDefaultDatabase();

  /// The shape that was reported: a port divided between producer-driven
  /// lines, and then somebody hangs an output node on it.
  Pipeline dividedPort({required EdgeMode andThen}) {
    final builder = PipelineBuilder(db, name: 'divided')
      ..add('natural_gas_generator', nodeId: 'gen')
      ..addSource('natural_gas')
      ..addSink('power')
      ..add('arbor_tree', nodeId: 'tree_a')
      ..add('arbor_tree', nodeId: 'tree_b')
      ..addSink('polluted_water')
      ..addSource('dirt')
      ..addSink('lumber')
      ..connectItem('src_natural_gas', 'gen', 'natural_gas')
      ..connect('gen', 'power_out', 'sink_power', 'in')
      ..connectItem('src_dirt', 'tree_a', 'dirt')
      ..connectItem('src_dirt', 'tree_b', 'dirt')
      ..connectItem('tree_a', 'sink_lumber', 'lumber')
      ..connectItem('tree_b', 'sink_lumber', 'lumber');
    final pipeline = builder.build();
    // Two producer-driven lines with no shares: between them they divide all
    // the generator's polluted water.
    final edges = <PipelineEdge>[
      ...pipeline.edges,
      PipelineEdge(
        id: 'to_a',
        fromNodeId: 'gen',
        fromPortId: 'polluted_water',
        toNodeId: 'tree_a',
        toPortId: 'polluted_water',
        mode: EdgeMode.push,
      ),
      PipelineEdge(
        id: 'to_b',
        fromNodeId: 'gen',
        fromPortId: 'polluted_water',
        toNodeId: 'tree_b',
        toPortId: 'polluted_water',
        mode: EdgeMode.push,
      ),
      PipelineEdge(
        id: 'to_sink',
        fromNodeId: 'gen',
        fromPortId: 'polluted_water',
        toNodeId: 'sink_polluted_water',
        toPortId: 'in',
        mode: andThen,
      ),
    ];
    return pipeline.copyWith(edges: edges);
  }

  test('a divided port knows it is divided', () {
    final ref = const PortRef('gen', 'polluted_water');
    expect(portIsFullyDivided(dividedPort(andThen: EdgeMode.pull), ref), isTrue,
        reason: 'two producer-driven lines with no shares take all of it');
  });

  test('and a line that joins the division does not brick the build', () {
    // Reported: "Adding polluted water output to (Ethanol) Petroleum
    // Generator zeroes entire build". A consumer-driven line on a port that
    // is already fully divided has nothing to take, and the build is refused
    // outright -- for an action that is only ever "send the rest somewhere".
    final refused = validatePipeline(dividedPort(andThen: EdgeMode.pull), db);
    expect(refused.map((i) => i.message).join(' '),
        contains('already spoken for'));

    final joined = validatePipeline(dividedPort(andThen: EdgeMode.push), db);
    expect(joined.where((i) => i.severity == IssueSeverity.error), isEmpty);
  });

  test('an over-committed build names the port rather than every port', () {
    // Reported: "Sometimes it lists every single node ... it's hard to tell
    // which one is the problem." The search that finds the one guilty port
    // ran a whole solve per candidate and was capped at 24 of them; the build
    // this fixture is has 26, so it got the wall of names -- and the one it
    // could not be bothered to find was the node its author had just added.
    final pipeline = PipelineShareCode.decode(
        File('test/fixtures/over_committed.txt').readAsStringSync().trim());
    final solution = PipelineSolver(db).solve(pipeline);
    expect(solution.status, SolveStatus.inconsistent);
    final hint = solution.issues
        .where((i) => i.severity == IssueSeverity.info)
        .map((i) => i.message)
        .join(' ');
    expect(hint, contains('Nothing here can take all the Oakshell'),
        reason: 'one port named, not a list of twenty-six');
  });

  test('and a share the simplex meant as nothing is written as nothing', () {
    // Reported: a build where three of four lines out of one port carried
    // shares of 6e-15 and 3e-15, which starved everything on the end of them
    // while reading as 0 % on screen.
    expect(asShare(5.9331240699613e-15), 0);
    expect(asShare(0.99999999999999911), 1);
    expect(asShare(0.25), 0.25);
  });
}
