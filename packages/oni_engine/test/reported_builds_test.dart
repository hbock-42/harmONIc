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

  test('an output node fed by several wires says what is really wrong', () {
    // Reported: "unsure why the negative draws of resources keep happening",
    // on a build whose four carbon dioxide lines all ran into one output node.
    // An output has no size of its own, so each line reading "half of what it
    // wants" means "half of whatever the other brings" -- which holds all four
    // suppliers to the same amount for ever after.
    final builder = PipelineBuilder(db, name: 'one bucket, four taps')
      ..add('natural_gas_generator', nodeId: 'gen')
      ..add('petroleum_generator', nodeId: 'pgen')
      ..addSource('natural_gas')
      ..addSource('petroleum')
      ..addSink('carbon_dioxide')
      ..addSink('power')
      ..connectItem('src_natural_gas', 'gen', 'natural_gas')
      ..connect('src_petroleum', 'out', 'pgen', 'fuel')
      ..connect('gen', 'power_out', 'sink_power', 'in')
      ..connect('pgen', 'power_out', 'sink_power', 'in')
      ..connectItem('gen', 'sink_carbon_dioxide', 'carbon_dioxide')
      ..connectItem('pgen', 'sink_carbon_dioxide', 'carbon_dioxide');
    final solution = PipelineSolver(db).solve(builder.build());

    final bucket = solution.issues.where(
        (i) => i.message.contains('an output node has no size of its own'));
    expect(bucket, isNotEmpty,
        reason: 'the old wording told the reader to divide something that has '
            'nothing to divide');

    // And it offers to do it, because four wires is four trips otherwise.
    final fix = bucket.first.fix;
    expect(fix, isNotNull);
    expect(fix!.producerDrivenEdgeIds.length, greaterThanOrEqualTo(2));
    // The wires are named as places to go, not only the node.
    expect(bucket.first.places.where((p) => p.edgeId != null), isNotEmpty);
  });

  group('a class port is a compatibility rule, not a choice', () {
    /// Reported: "Ethanol Distiller isn't tolerating combining Gum Wood with
    /// Arbor Tree and Oakshell Molt for the Lumber input line, even when set
    /// to Any." Any was exactly right; what settled the port was the first
    /// wire into it.
    Pipeline woodyard() => (PipelineBuilder(db, name: 'woodyard')
          ..add('arbor_tree', nodeId: 'tree')
          ..add('gum_palm', nodeId: 'palm')
          ..add('ethanol_distiller', nodeId: 'still'))
        .build();

    test('so any wood joins any other wood', () {
      final spec = db.processOrThrow('ethanol_distiller');
      final wood = spec.portById('wood')!;
      final withLumber = woodyard().copyWith(edges: [
        const PipelineEdge(
          id: 'lumber_line',
          fromNodeId: 'tree',
          fromPortId: 'lumber',
          toNodeId: 'still',
          toPortId: 'wood',
        ),
      ]);
      final still = withLumber.nodeOrThrow('still');

      expect(
          portAcceptsThrough(db, withLumber, still, spec, wood, 'gum_wood'),
          isTrue,
          reason: 'it burns any wood and makes the same ethanol either way');
      // And still refuses what is not wood at all.
      expect(portAcceptsThrough(db, withLumber, still, spec, wood, 'coal'),
          isFalse);
    });

    test('and a recipe whose output *is* its input still decides', () {
      // The four that tie an output to an input -- Metal Refinery, the metal
      // Rock Crusher and the two Smooth Hatches -- are the reason this rule
      // exists. Iron ore in, iron out, and copper ore may not join it.
      final spec = db.processOrThrow('metal_refinery');
      final ore = spec.portById('metal_ore')!;
      final base = (PipelineBuilder(db, name: 'refinery')
            ..add('metal_refinery', nodeId: 'refinery')
            ..addSource('iron_ore'))
          .build();
      final wired = base.copyWith(edges: [
        const PipelineEdge(
          id: 'ore_line',
          fromNodeId: 'src_iron_ore',
          fromPortId: 'out',
          toNodeId: 'refinery',
          toPortId: 'metal_ore',
        ),
      ]);
      final node = wired.nodeOrThrow('refinery');

      expect(portAcceptsThrough(db, wired, node, spec, ore, 'iron_ore'), isTrue);
      expect(portAcceptsThrough(db, wired, node, spec, ore, 'copper_ore'),
          isFalse,
          reason: 'a refinery fed iron ore has decided what it is making');
    });
  });

  test('a port promised twice over says so, and offers the way out', () {
    // Reported: "linking Cuddle Pip's dirt back to Arbor Tree zeroes a bunch
    // of stuff". A consumer-driven line with no share of its own brings the
    // port's *whole* demand, so the Compost already pushing dirt into the same
    // port had nowhere to put it -- and the only arithmetic that fits is
    // everything at zero.
    final base = (PipelineBuilder(db, name: 'promised twice')
          ..add('arbor_tree', nodeId: 'tree')
          ..add('compost', nodeId: 'heap')
          ..add('cuddle_pip', nodeId: 'pip')
          ..addSource('polluted_dirt'))
        .build();
    final pipeline = base.copyWith(edges: [
      const PipelineEdge(
        id: 'pushed',
        fromNodeId: 'heap',
        fromPortId: 'dirt',
        toNodeId: 'tree',
        toPortId: 'dirt',
        mode: EdgeMode.push,
      ),
      const PipelineEdge(
        id: 'pulled',
        fromNodeId: 'pip',
        fromPortId: 'dirt',
        toNodeId: 'tree',
        toPortId: 'dirt',
      ),
    ]);

    final issue = validatePipeline(pipeline, db).firstWhere(
        (i) => i.message.contains('promised twice over'),
        orElse: () => throw StateError('nothing said'));
    expect(issue.severity, IssueSeverity.warning,
        reason: 'it is a mistake worth naming, not a build worth refusing');
    expect(issue.fix?.producerDrivenEdgeIds, ['pulled']);
    expect(issue.places.map((p) => p.edgeId), contains('pulled'));

    // And with the consumer-driven line given room, nothing is said.
    final shared = pipeline.copyWith(edges: [
      for (final e in pipeline.edges)
        if (e.id == 'pulled') e.copyWith(share: 0.5) else e,
    ]);
    expect(
      validatePipeline(shared, db)
          .where((i) => i.message.contains('promised twice over')),
      isEmpty,
    );
  });

  test('a loose end on a settled build does not call the whole thing loose',
      () {
    // Reported: hanging a Power output on a build that solved said "nothing
    // sets the size of this build, so every amount in it could be anything"
    // -- while every other figure on screen was still right, and unchanged.
    // The build was not unmoored; one new node had no size.
    final settled = PipelineShareCode.decode(
        File('test/fixtures/settled_build.txt').readAsStringSync().trim());
    final before = PipelineSolver(db).solve(settled);
    expect(before.status, SolveStatus.solved);

    final withOutput = settled.copyWith(
      nodes: [
        ...settled.nodes,
        const PipelineNode(id: 'spare', specId: 'sink:power'),
      ],
      edges: [
        ...settled.edges,
        const PipelineEdge(
          id: 'spare_power',
          fromNodeId: 'natural_gas_generator_41',
          fromPortId: 'power_out',
          toNodeId: 'spare',
          toPortId: 'in',
        ),
      ],
    );
    final after = PipelineSolver(db).solve(withOutput);
    final said = after.issues.map((i) => i.message).join();

    expect(said, contains('Nothing says how big the Power output is'));
    expect(said, isNot(contains('every amount in it could be anything')),
        reason: 'the rest of the build is settled');
    // And it really is settled: every figure it had is the figure it keeps.
    for (final entry in before.nodes.entries) {
      expect(after.nodes[entry.key]!.count, closeTo(entry.value.count, 1e-6),
          reason: entry.key);
    }
  });

  group('when no single port explains it', () {
    /// A generator whose power is drawn by one pinned crusher and nothing
    /// else: the port has to hand over exactly what it makes, and at these
    /// sizes it cannot. Venting the power is the one fix.
    PipelineBuilder loop(String suffix) => PipelineBuilder(db, name: 'loop')
      ..add('natural_gas_generator', nodeId: 'gen$suffix')
      ..add('rock_crusher_sand', nodeId: 'crusher$suffix')
      ..connect('gen$suffix', 'power_out', 'crusher$suffix', 'power_in')
      ..pinCount('gen$suffix', 2)
      ..pinCount('crusher$suffix', 1);

    test('one of them is named on its own', () {
      final solution = PipelineSolver(db).solve(loop('').build());
      expect(solution.status, SolveStatus.inconsistent);
      expect(solution.issues.map((i) => i.message).join(),
          contains('Nothing here can take all the'));
    });

    test('and two of them are named together', () {
      // Reported on a build where venting any single port still left it
      // unsolvable, and the reader got the whole list to guess from. Two
      // independent loops need two vents, and neither alone is the answer.
      final a = loop('_a').build();
      final b = loop('_b').build();
      final both = a.copyWith(
        nodes: [...a.nodes, ...b.nodes],
        edges: [...a.edges, ...b.edges],
        pins: [...a.pins, ...b.pins],
      );

      final said = PipelineSolver(db)
          .solve(both)
          .issues
          .map((i) => i.message)
          .join(' ');
      expect(said, contains('No single port explains this one: it takes two'));
      expect(said, contains('Natural Gas Generator’s power'));
    });

    test('and three loops are named as three, not as a list', () {
      // Reported with a picture: thirty-one ports named and none of them
      // marked. The pair search is exact and stops at two, so a build wanting
      // three vented defeated it exactly as thoroughly as one wanting
      // thirty — and both got the same wall of names. It looks for a set now,
      // greedily, the way the reader was doing it by hand.
      var all = loop('_0').build();
      for (var i = 1; i < 3; i++) {
        final next = loop('_$i').build();
        all = all.copyWith(
          nodes: [...all.nodes, ...next.nodes],
          edges: [...all.edges, ...next.edges],
          pins: [...all.pins, ...next.pins],
        );
      }

      final issues = PipelineSolver(db).solve(all).issues;
      final said = issues.map((i) => i.message).join(' ');
      expect(said, contains('it takes three'));
      expect(said, isNot(contains('No one of these is the problem on its own')),
          reason: 'the list is what this replaces');

      // And every port it names is one you can go and act on.
      final named = issues
          .expand((i) => i.places)
          .where((p) => p.portId != null)
          .toList();
      expect(named, hasLength(3));
    });

    test('and past that it says so rather than handing over a list', () {
      // Five loops is more than a pair, and the useful thing to know is that
      // hunting for the one port at fault is a waste of an afternoon.
      var all = loop('_0').build();
      for (var i = 1; i < 5; i++) {
        final next = loop('_$i').build();
        all = all.copyWith(
          nodes: [...all.nodes, ...next.nodes],
          edges: [...all.edges, ...next.edges],
          pins: [...all.pins, ...next.pins],
        );
      }

      final said =
          PipelineSolver(db).solve(all).issues.map((i) => i.message).join(' ');
      expect(said, contains('No one of these is the problem on its own'));
    });
  });
}
