import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Letting the solver choose the splits, end to end.
///
/// `docs/CHOOSING-SHARES.md` is the decision this implements, including the
/// promise that matters most: on a build with no freedom in it, the optimiser
/// and the ordinary solver must give the same answer. Two solvers that
/// disagree would be worse than one that cannot optimise.
void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  /// 10 kg/s of iron ore, and two ways to turn it into metal: a Metal Refinery
  /// at one for one, and a Rock Crusher at half that. Nobody has said how the
  /// ore divides.
  Pipeline twoWays() => (PipelineBuilder(db, name: 'Ore')
        ..addSource('iron_ore')
        ..add('metal_refinery', nodeId: 'refinery')
        ..add('rock_crusher_metal', nodeId: 'crusher')
        ..addSink('iron')
        ..connectItem('src_iron_ore', 'refinery', 'iron_ore')
        ..connectItem('src_iron_ore', 'crusher', 'iron_ore')
        ..connectItem('refinery', 'sink_iron', 'refined_metal')
        ..connectItem('crusher', 'sink_iron', 'refined_metal')
        ..pinRate('src_iron_ore', sourcePortId, 10000))
      .build();

  test('an even split is a fair guess and not the best one', () {
    // What the app says today: the ore divides by the rule nobody chose, and
    // two thirds of the metal comes back.
    final asDrawn = solver.solve(twoWays());
    expect(asDrawn.status, SolveStatus.solved);
    expect(asDrawn.nodes['sink_iron']!.count, closeTo(6666.67, 0.01));

    // What it could be: everything through the refinery, kilogram for
    // kilogram. Half the metal again, and nobody had to work out the split.
    final best = mostOf(twoWays(), db, 'iron');
    expect(best.status, LpStatus.optimal);
    expect(best.ratePerSecond, closeTo(10000, 1e-6));
    expect(best.nodeCounts['refinery'], closeTo(4, 1e-9));
    expect(best.nodeCounts['crusher'], closeTo(0, 1e-9));
  });

  test('and the ordinary solver reproduces it exactly', () {
    // The promise that keeps there being one solver: the simplex chooses, and
    // then every number on screen comes from the elimination as always.
    final best = mostOf(twoWays(), db, 'iron');
    final chosen = withShares(twoWays(), db, best);
    final solved = solver.solve(chosen);

    expect(solved.status, SolveStatus.solved);
    expect(solved.nodes['sink_iron']!.count, closeTo(10000, 1e-6));
    for (final entry in best.nodeCounts.entries) {
      expect(solved.nodes[entry.key]!.count, closeTo(entry.value, 1e-6),
          reason: entry.key);
    }
    for (final entry in best.edgeFlows.entries) {
      expect(solved.edgeFlows[entry.key], closeTo(entry.value, 1e-6),
          reason: entry.key);
    }
  });

  test('a port with one edge is left alone', () {
    // There was nothing to choose there, and writing a share onto it would
    // fill the inspector with decisions nobody made.
    final chosen = withShares(twoWays(), db, mostOf(twoWays(), db, 'iron'));
    final untouched = chosen.edges
        .where((e) => e.fromNodeId == 'refinery' || e.fromNodeId == 'crusher');
    expect(untouched, isNotEmpty);
    for (final edge in untouched) {
      // Their target is shared, so they carry a pull share; their own port is
      // not, so they were not turned into push lines.
      expect(edge.mode, EdgeMode.pull, reason: edge.id);
    }
  });

  group('agreeing with the solver where there is nothing to choose', () {
    for (final template in pipelineTemplates) {
      test('the ${template.name} build', () {
        final pipeline = template.build(db);
        final solved = solver.solve(pipeline);
        if (solved.status != SolveStatus.solved) return;

        // Ask for something the build makes, so the objective is real.
        final item = solved.externalOutputs.keys.firstWhere(
            (id) => pipeline.nodes.any((n) =>
                db.processOrThrow(n.specId).kind == ProcessKind.sink &&
                db.processOrThrow(n.specId).inputs.any((p) => p.itemId == id)),
            orElse: () => '');
        if (item.isEmpty) return;

        final best = mostOf(pipeline, db, item);
        expect(best.status, LpStatus.optimal, reason: template.name);
        final after = solver.solve(withShares(pipeline, db, best));
        expect(after.status, SolveStatus.solved, reason: template.name);
        for (final node in pipeline.nodes) {
          expect(after.nodes[node.id]!.count,
              closeTo(solved.nodes[node.id]!.count, 1e-6),
              reason: '${template.name}: ${node.id}');
        }
      });
    }
  });

  group('the same question from the other end', () {
    /// The same two ways of refining, but now you have said what you want out
    /// of it: 5 kg/s of iron.
    Pipeline wanting() {
      final pipeline = twoWays();
      return pipeline.copyWith(pins: [
        const PortRatePin(nodeId: 'sink_iron', portId: 'in', ratePerSecond: 5000),
      ]);
    }

    test('the least ore that gets you what you asked for', () {
      // Split evenly it takes 7.5 kg/s of ore to make 5 of metal. Through the
      // refinery alone it takes 5, and the crusher stands idle.
      expect(solver.solve(wanting()).nodes['src_iron_ore']!.count,
          closeTo(7500, 1e-6));

      final least = leastOf(wanting(), db, 'iron_ore');
      expect(least.status, LpStatus.optimal);
      expect(least.ratePerSecond, closeTo(5000, 1e-6));
      expect(least.nodeCounts['crusher'], closeTo(0, 1e-9));
    });

    test('and the ordinary solver reproduces that too', () {
      final chosen = withShares(wanting(), db, leastOf(wanting(), db, 'iron_ore'));
      final solved = solver.solve(chosen);

      expect(solved.status, SolveStatus.solved);
      expect(solved.nodes['src_iron_ore']!.count, closeTo(5000, 1e-6));
      expect(solved.nodes['sink_iron']!.count, closeTo(5000, 1e-6),
          reason: 'you still get what you asked for');
    });

    test('with nothing asked for, the cheapest build is no build', () {
      // Honest rather than clever: the least ore that makes nothing is none,
      // and a build with no amount set is asking for nothing.
      final least = leastOf(twoWays().copyWith(pins: const []), db, 'iron_ore');
      expect(least.status, LpStatus.optimal);
      expect(least.ratePerSecond, closeTo(0, 1e-9));
    });
  });

  group('the totals that are not a port', () {
    Pipeline wanting() => twoWays().copyWith(pins: [
          const PortRatePin(
              nodeId: 'sink_iron', portId: 'in', ratePerSecond: 5000),
        ]);

    test('the cheapest way to run it is not the cheapest way to build it', () {
      // The whole reason these are three questions and not one. A Metal
      // Refinery draws 1.2 kW and a Rock Crusher 240 W, so the least power is
      // the crusher — at the cost of twice the ore, more heat and more floor.
      final power = leastTotal(wanting(), db, BuildTotal.power);
      expect(power.status, LpStatus.optimal);
      expect(power.nodeCounts['refinery'], closeTo(0, 1e-9));
      expect(power.nodeCounts['crusher'], greaterThan(0));

      // Heat and floor both say the opposite.
      for (final total in [BuildTotal.heat, BuildTotal.floor]) {
        final best = leastTotal(wanting(), db, total);
        expect(best.status, LpStatus.optimal, reason: '$total');
        expect(best.nodeCounts['crusher'], closeTo(0, 1e-9), reason: '$total');
      }
    });

    test('and the ordinary solver reproduces each of them', () {
      for (final total in BuildTotal.values) {
        final best = leastTotal(wanting(), db, total);
        final solved = solver.solve(withShares(wanting(), db, best));
        expect(solved.status, SolveStatus.solved, reason: '$total');
        for (final entry in best.nodeCounts.entries) {
          expect(solved.nodes[entry.key]!.count, closeTo(entry.value, 1e-6),
              reason: '$total: ${entry.key}');
        }
        // And you still get what you asked for, whichever total was chased.
        expect(solved.nodes['sink_iron']!.count, closeTo(5000, 1e-6),
            reason: '$total');
      }
    });

    test('a build of nothing but boundaries has no total to shrink', () {
      // Supplies and outputs draw nothing, emit nothing and stand on nothing,
      // so there is no objective to write.
      final bare = (PipelineBuilder(db, name: 'bare')
            ..addSource('water')
            ..addSink('water')
            ..connectItem('src_water', 'sink_water', 'water'))
          .build();
      expect(leastTotal(bare, db, BuildTotal.power).status,
          LpStatus.infeasible);
    });
  });

  group('what it will not argue with', () {
    test('a share you set yourself', () {
      // An explicit share is a decision. The optimiser works around it rather
      // than over it, so a build told to send a quarter to the crusher keeps
      // sending a quarter to the crusher.
      final pipeline = twoWays();
      final toCrusher =
          pipeline.edges.firstWhere((e) => e.toNodeId == 'crusher');
      final fixed = pipeline.copyWith(edges: [
        for (final e in pipeline.edges)
          if (e.id == toCrusher.id)
            e.copyWith(mode: EdgeMode.push, share: 0.25)
          else
            e,
      ]);

      final best = mostOf(fixed, db, 'iron');
      expect(best.status, LpStatus.optimal);
      expect(best.edgeFlows[toCrusher.id], closeTo(2500, 1e-6));
      // Three quarters at one for one, a quarter at half: 8.75 kg/s.
      expect(best.ratePerSecond, closeTo(8750, 1e-6));
    });

    test('a pin', () {
      // Two crushers, whatever that costs the answer: the ore they eat is ore
      // the refinery does not get, and the optimiser divides what is left.
      final pipeline = twoWays();
      final pinned = pipeline.copyWith(pins: [
        ...pipeline.pins,
        const BuildingCountPin(nodeId: 'crusher', count: 2),
      ]);

      final best = mostOf(pinned, db, 'iron');
      expect(best.status, LpStatus.optimal);
      expect(best.nodeCounts['crusher'], closeTo(2, 1e-9));
      // Two crushers eat 5 kg/s and give back 2.5; the other 5 goes through
      // the refinery whole. 7.5 kg/s, against 10 with a free hand.
      expect(best.ratePerSecond, closeTo(7500, 1e-6));
    });

    test('but an unpinned supply has no most: it is a missing limit', () {
      // A supply node stands for something outside the build, and nothing
      // outside the build is bounded. "As much as you like" is not an answer,
      // and saying so is better than picking a number.
      final unpinned = twoWays().copyWith(pins: const []);
      expect(mostOf(unpinned, db, 'iron').status, LpStatus.unbounded);
    });

    test('and pins that contradict each other are said to be impossible', () {
      final impossible = twoWays().copyWith(pins: [
        const BuildingCountPin(nodeId: 'refinery', count: 1),
        const BuildingCountPin(nodeId: 'refinery', count: 2),
      ]);
      expect(mostOf(impossible, db, 'iron').status, LpStatus.infeasible);
    });

    test('and an item nothing collects has no answer', () {
      expect(mostOf(twoWays(), db, 'oxygen').status, LpStatus.infeasible);
    });
  });
  group('the least of nothing', () {
    /// Reported: press "Use as little as possible" on a pinned ore supply and
    /// the build empties out — every share zero, every count zero, and a
    /// banner saying nothing sets its size. The minimum was real and useless:
    /// the cheapest way to use no ore is to make no metal.
    Pipeline fork(GameDatabase db, {double? supply, double? output}) {
      final b = PipelineBuilder(db, name: 'fork')
        ..addSource('iron_ore')
        ..add('metal_refinery', nodeId: 'ref')
        ..add('rock_crusher_metal', nodeId: 'crush')
        ..addSink('iron', nodeId: 'out')
        ..connect('src_iron_ore', sourcePortId, 'ref', 'metal_ore')
        ..connect('src_iron_ore', sourcePortId, 'crush', 'metal_ore')
        ..connect('ref', 'refined_metal', 'out', sinkPortId)
        ..connect('crush', 'refined_metal', 'out', sinkPortId);
      if (supply != null) b.pinCount('src_iron_ore', supply);
      if (output != null) b.pinCount('out', output);
      return b.build();
    }

    test('a build asked for nothing has no least', () {
      final best = leastOf(fork(db, supply: 200), db, 'iron_ore');

      expect(best.status, LpStatus.optimal, reason: 'the simplex did its job');
      expect(best.runsNothing, isTrue);
      expect(best.isAnswer, isFalse, reason: 'so nothing is applied');
    });

    test('and neither has one with no amounts at all', () {
      expect(leastOf(fork(db), db, 'iron_ore').isAnswer, isFalse);
    });

    test('but ask it for iron and it answers', () {
      final best = leastOf(fork(db, output: 200), db, 'iron_ore');

      expect(best.isAnswer, isTrue);
      expect(best.ratePerSecond, closeTo(200, 1e-6),
          reason: 'the refinery is one for one; the crusher would need more');
      final applied = withShares(fork(db, output: 200), db, best);
      expect(PipelineSolver(db).solve(applied).status, SolveStatus.solved);
    });

    test('the same guard covers the totals in the bottom bar', () {
      // Least power, with nothing asked for, is also "build nothing".
      expect(leastTotal(fork(db, supply: 200), db, BuildTotal.power).isAnswer,
          isFalse);
      expect(leastTotal(fork(db, output: 200), db, BuildTotal.power).isAnswer,
          isTrue);
    });
  });

}
