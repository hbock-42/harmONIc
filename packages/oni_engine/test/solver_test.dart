import 'dart:convert';

import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  /// water source → electrolyzer → oxygen sink + hydrogen sink
  PipelineBuilder basic() {
    final b = PipelineBuilder(db, name: 'basic oxygen');
    b.addSource('water');
    b.add('electrolyzer', nodeId: 'elec');
    b.addSink('oxygen');
    b.addSink('hydrogen');
    b.connectItem('src_water', 'elec', 'water');
    b.connectItem('elec', 'sink_oxygen', 'oxygen');
    b.connectItem('elec', 'sink_hydrogen', 'hydrogen');
    return b;
  }

  group('pinning', () {
    test('a building count scales the whole graph', () {
      final b = basic()..pinCount('elec', 3);
      final s = solver.solve(b.build());

      expect(s.status, SolveStatus.solved);
      expect(s.nodes['elec']!.count, closeTo(3, 1e-9));
      // Sources/sinks are 1 unit == 1 g/s, so their count reads as a rate.
      expect(s.nodes['src_water']!.count, closeTo(3000, 1e-6));
      expect(s.nodes['sink_oxygen']!.count, closeTo(2664, 1e-6));
      expect(s.nodes['sink_hydrogen']!.count, closeTo(336, 1e-6));
      expect(s.powerConsumedWatts, closeTo(360, 1e-6));
    });

    test('a supply rate works backwards to a building count', () {
      // "I have 10 kg/s of water."
      final b = basic()..pinRate('src_water', sourcePortId, 10000);
      final s = solver.solve(b.build());

      expect(s.status, SolveStatus.solved);
      expect(s.nodes['elec']!.count, closeTo(10, 1e-9));
      expect(s.nodes['sink_oxygen']!.count, closeTo(8880, 1e-6));
    });

    test('a wanted output works backwards too', () {
      // "I want 1 kg/s of oxygen."
      final b = basic()..pinRate('sink_oxygen', sinkPortId, 1000);
      final s = solver.solve(b.build());

      expect(s.status, SolveStatus.solved);
      expect(s.nodes['elec']!.count, closeTo(1000 / 888, 1e-9));
      expect(s.nodes['src_water']!.count, closeTo(1000 / 0.888, 1e-6));
    });

    test('a stockpile plus a duration is just a rate', () {
      // 600 kg of water, made to last 10 cycles = 6000 s → 100 g/s.
      final b = basic()
        ..pinStock('src_water', sourcePortId,
            amount: 600000, durationSeconds: 10 * secondsPerCycle);
      final s = solver.solve(b.build());

      expect(s.nodes['src_water']!.count, closeTo(100, 1e-6));
      expect(s.nodes['elec']!.count, closeTo(0.1, 1e-9));
    });

    test('the solution scales linearly with the pin', () {
      final one = solver.solve((basic()..pinCount('elec', 1)).build());
      final seven = solver.solve((basic()..pinCount('elec', 7)).build());
      for (final id in one.nodes.keys) {
        expect(seven.nodes[id]!.count, closeTo(one.nodes[id]!.count * 7, 1e-6));
      }
    });
  });

  group('balances', () {
    test('unconnected input ports become required inputs', () {
      final b = PipelineBuilder(db, name: 'bare')
        ..add('electrolyzer', nodeId: 'elec')
        ..pinCount('elec', 1);
      final s = solver.solve(b.build());

      expect(s.externalInputs['water'], closeTo(1000, 1e-9));
      expect(s.externalOutputs['oxygen'], closeTo(888, 1e-9));
      expect(s.externalOutputs['hydrogen'], closeTo(112, 1e-9));
      expect(s.shortages, isEmpty, reason: 'nothing is *half* fed here');
    });

    test('fed ports have no shortage', () {
      final s = solver.solve((basic()..pinCount('elec', 2.5)).build());
      for (final balance in s.portBalances) {
        expect(balance.shortage, closeTo(0, 1e-6), reason: '${balance.ref}');
      }
    });

    test('an output port with no edges is surplus, not an error', () {
      final b = PipelineBuilder(db, name: 'vented hydrogen')
        ..addSource('water')
        ..add('electrolyzer', nodeId: 'elec')
        ..addSink('oxygen')
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'sink_oxygen', 'oxygen')
        ..pinCount('elec', 1);
      final s = solver.solve(b.build());

      expect(s.status, SolveStatus.solved);
      expect(s.externalOutputs['hydrogen'], closeTo(112, 1e-9));
      expect(s.issues.where((i) => i.isError), isEmpty);
    });

    test('push shares split an output between consumers', () {
      final b = PipelineBuilder(db, name: 'split')
        ..add('electrolyzer', nodeId: 'elec')
        ..addSink('oxygen', nodeId: 'a')
        ..addSink('oxygen', nodeId: 'b')
        ..connectItem('elec', 'a', 'oxygen', mode: EdgeMode.push)
        ..connectItem('elec', 'b', 'oxygen', mode: EdgeMode.push)
        ..pinCount('elec', 1);
      final s = solver.solve(b.build());

      expect(s.nodes['a']!.count, closeTo(444, 1e-6));
      expect(s.nodes['b']!.count, closeTo(444, 1e-6));
    });

    test('an explicit push share leaves the rest as surplus', () {
      final b = PipelineBuilder(db, name: 'partial')
        ..add('electrolyzer', nodeId: 'elec')
        ..addSink('oxygen', nodeId: 'a')
        ..connect('elec', 'oxygen', 'a', sinkPortId,
            mode: EdgeMode.push, share: 0.25)
        ..pinCount('elec', 1);
      final s = solver.solve(b.build());

      expect(s.nodes['a']!.count, closeTo(222, 1e-6));
      expect(s.externalOutputs['oxygen'], closeTo(666, 1e-6));
    });
  });

  group('demand-driven edges', () {
    test('a producer is sized by what its consumers pull', () {
      // The whole point: 20 dupes breathe 2000 g/s, so how many Electrolyzers?
      final b = PipelineBuilder(db, name: 'life support')
        ..addSource('water')
        ..add('electrolyzer', nodeId: 'elec')
        ..add('duplicant', nodeId: 'dupes')
        ..addSink('hydrogen')
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'dupes', 'oxygen')
        ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
        ..pinCount('dupes', 20);
      final s = solver.solve(b.build());

      expect(s.status, SolveStatus.solved);
      expect(s.nodes['elec']!.count, closeTo(2000 / 888, 1e-9));
      expect(s.nodes['src_water']!.count, closeTo(2000 / 0.888, 1e-6));
    });

    test('two consumers add up instead of splitting a fixed ratio', () {
      // Each consumer is independent, so both need pinning — and the producer
      // covers their sum rather than being carved 50/50.
      final b = PipelineBuilder(db, name: 'shared oxygen')
        ..add('electrolyzer', nodeId: 'elec')
        ..add('duplicant', nodeId: 'dupes')
        ..add('oxylite_refinery', nodeId: 'oxylite')
        ..addSink('hydrogen')
        ..connectItem('elec', 'dupes', 'oxygen')
        ..connectItem('elec', 'oxylite', 'oxygen')
        ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
        ..pinCount('dupes', 6)
        ..pinCount('oxylite', 1);
      final s = solver.solve(b.build());

      expect(s.status, SolveStatus.solved);
      // 6 dupes × 100 g/s + one refinery × 600 g/s = 1200 g/s of oxygen.
      expect(s.nodes['elec']!.count, closeTo(1200 / 888, 1e-9));
      expect(s.edgeFlows.values.reduce((a, b) => a > b ? a : b),
          closeTo(600, 1e-6));
    });

    test('a generator is sized by the grid hanging off it', () {
      // Two sieves and two skimmers draw 480 W, so 0.8 of a coal generator
      // covers them — meaning build one and expect it idle a fifth of the time.
      final b = PipelineBuilder(db, name: 'grid')
        ..add('coal_generator', nodeId: 'gen')
        ..add('water_sieve', nodeId: 'sieve')
        ..add('carbon_skimmer', nodeId: 'skimmer')
        ..connectItem('gen', 'sieve', 'power')
        ..connectItem('gen', 'skimmer', 'power')
        ..pinCount('sieve', 2)
        ..pinCount('skimmer', 2);
      final s = solver.solve(b.build());

      expect(s.status, SolveStatus.solved);
      expect(s.nodes['gen']!.count, closeTo(480 / 600, 1e-9));
      expect(s.nodes['gen']!.wholeCount, 1);
      expect(s.nodes['gen']!.utilisation, closeTo(0.8, 1e-9));
      expect(s.externalInputs['coal'], closeTo(800, 1e-6));
    });

    test('a spare-power outlet is not counted as a consumer', () {
      // Regression: sinks stand for the world outside the build, so routing
      // 360 W of surplus into one must not read as 360 W of extra draw.
      final b = PipelineBuilder(db, name: 'boundary')
        ..add('coal_generator', nodeId: 'gen')
        ..add('water_sieve', nodeId: 'sieve')
        ..addSink('power', nodeId: 'spare')
        ..connectItem('gen', 'sieve', 'power')
        ..connectItem('gen', 'spare', 'power')
        ..pinCount('gen', 1)
        ..pinCount('sieve', 2);
      final s = solver.solve(b.build());

      expect(s.powerConsumedWatts, closeTo(240, 1e-6));
      expect(s.powerGeneratedWatts, closeTo(600, 1e-6));
      expect(s.netPowerWatts, closeTo(360, 1e-6));
      expect(s.totalHeatKdtu, closeTo(9 + 2 * 4, 1e-6),
          reason: 'generator + two sieves; the sink itself emits nothing');
    });

    test('a spare-power outlet absorbs what the grid does not use', () {
      final b = PipelineBuilder(db, name: 'grid with slack')
        ..add('coal_generator', nodeId: 'gen')
        ..add('water_sieve', nodeId: 'sieve')
        ..addSink('power', nodeId: 'spare')
        ..connectItem('gen', 'sieve', 'power')
        ..connectItem('gen', 'spare', 'power')
        ..pinCount('gen', 1)
        ..pinCount('sieve', 2);
      final s = solver.solve(b.build());

      expect(s.status, SolveStatus.solved);
      expect(s.nodes['spare']!.count, closeTo(600 - 240, 1e-6));
    });

    test('a forgotten outlet is explained, not just rejected', () {
      // Hydrogen is pulled by the generator, so the Electrolyzer's hydrogen port
      // must be fully consumed — but the water pin says otherwise.
      final b = PipelineBuilder(db, name: 'no vent')
        ..addSource('water')
        ..add('electrolyzer', nodeId: 'elec')
        ..add('hydrogen_generator', nodeId: 'hgen')
        ..addSink('power', nodeId: 'spare')
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'hgen', 'hydrogen')
        ..connectItem('hgen', 'spare', 'power')
        ..pinCount('elec', 1)
        ..pinCount('hgen', 5);
      final s = solver.solve(b.build());

      expect(s.status, SolveStatus.inconsistent);
      // And it names the one port at fault rather than every port that pulls:
      // the water and the power are innocent here.
      final hints = [
        for (final issue in s.issues)
          if (issue.severity == IssueSeverity.info) issue.message,
      ];
      expect(hints, hasLength(1));
      expect(hints.single, contains('Electrolyzer\u2019s hydrogen'));
      expect(hints.single, contains('output node'));
    });

    test('and a build with two ways out offers both', () {
      // The SPOM that powers itself: the generator makes seven times what the
      // Electrolyzer draws, so either the hydrogen or the power has to have
      // somewhere to overflow. Both are real answers; the water feeding it is
      // not, because venting that only shrinks the build to nothing.
      final b = PipelineBuilder(db, name: 'self-powered')
        ..addSource('water')
        ..add('electrolyzer', nodeId: 'elec')
        ..add('hydrogen_generator', nodeId: 'hgen')
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'hgen', 'hydrogen')
        ..connect('hgen', 'power_out', 'elec', 'power_in')
        ..pinCount('elec', 1);
      final s = solver.solve(b.build());

      expect(s.status, SolveStatus.inconsistent);
      final hints = [
        for (final issue in s.issues)
          if (issue.severity == IssueSeverity.info) issue.message,
      ];
      // One sentence naming both, not one sentence each: the same forty
      // words repeated per port is what made a real build unreadable.
      expect(hints, hasLength(1));
      expect(hints.join('\n'), contains('Electrolyzer\u2019s hydrogen'));
      expect(hints.join('\n'), contains('Hydrogen Generator\u2019s power'));
      expect(hints.join('\n'), isNot(contains('water')));
    });
  });

  group('power as an ordinary item', () {
    test('a SPOM nets out positive', () {
      // 1 electrolyzer → 112 g/s H2 → 1.12 hydrogen generators → 896 W,
      // against 120 W of electrolyzer draw.
      final b = PipelineBuilder(db, name: 'spom')
        ..addSource('water')
        ..add('electrolyzer', nodeId: 'elec')
        ..add('hydrogen_generator', nodeId: 'hgen')
        ..addSink('oxygen')
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'hgen', 'hydrogen')
        ..connectItem('elec', 'sink_oxygen', 'oxygen')
        ..pinCount('elec', 1);
      final s = solver.solve(b.build());

      expect(s.nodes['hgen']!.count, closeTo(1.12, 1e-9));
      expect(s.powerGeneratedWatts, closeTo(896, 1e-6));
      expect(s.powerConsumedWatts, closeTo(120, 1e-6));
      expect(s.netPowerWatts, closeTo(776, 1e-6));
    });

    test('a power loop solves without special handling', () {
      // The hydrogen generator feeds the electrolyzer's own power port: a real
      // cycle in the graph, which the linear system swallows whole. The spare
      // node is where the leftover power goes.
      final b = PipelineBuilder(db, name: 'spom loop')
        ..addSource('water')
        ..add('electrolyzer', nodeId: 'elec')
        ..add('hydrogen_generator', nodeId: 'hgen')
        ..addSink('power', nodeId: 'spare')
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'hgen', 'hydrogen')
        ..connectItem('hgen', 'elec', 'power')
        ..connectItem('hgen', 'spare', 'power')
        ..pinCount('elec', 1);
      final s = solver.solve(b.build());

      expect(s.status, SolveStatus.solved);
      expect(s.nodes['hgen']!.count, closeTo(1.12, 1e-9));
      expect(s.externalInputs['power'] ?? 0, closeTo(0, 1e-6),
          reason: 'the electrolyzer powers itself off its own hydrogen');
      expect(s.nodes['spare']!.count, closeTo(776, 1e-6));
    });
  });

  group('failure modes', () {
    test('no pin leaves everything free', () {
      final s = solver.solve(basic().build());
      expect(s.status, SolveStatus.underdetermined);
      expect(s.freeNodeIds, isNotEmpty);
      expect(s.isUsable, isTrue, reason: 'the UI still shows a zeroed graph');
    });

    group('the message it gives when it cannot work out a scale', () {
      PipelineSolution unscaled() {
        final b = PipelineBuilder(db, name: 'no scale')
          ..addSource('water')
          ..add('electrolyzer', nodeId: 'elec')
          ..connectItem('src_water', 'elec', 'water');
        return solver.solve(b.build());
      }

      String messageOf(PipelineSolution solution) => solution.issues
          .firstWhere((i) => i.severity == IssueSeverity.warning &&
              i.message.contains('size of this build'))
          .message;

      test('names the thing, not its internal id', () {
        final solution = unscaled();
        final free = solution.freeNodeIds.single;
        // "Electrolyzer", not "elec".
        expect(messageOf(solution), contains('Electrolyzer'));
        expect(messageOf(solution), isNot(contains(free)));
      });

      test('avoids words the reader has never been taught', () {
        final message = messageOf(unscaled()).toLowerCase();
        // "Pin" is what the code calls it. Nothing on screen ever explains it.
        expect(message, isNot(contains('pin')));
        expect(message, isNot(contains('underdetermined')));
        expect(message, isNot(contains('node')));
      });

      test('says what to do about it, in the words the buttons use', () {
        expect(messageOf(unscaled()), contains('Give an amount for'));
      });

      test('lists the candidates when there is more than one', () {
        final b = PipelineBuilder(db, name: 'two islands')
          ..add('electrolyzer', nodeId: 'elec')
          ..add('coal_generator', nodeId: 'gen');
        final message = messageOf(solver.solve(b.build()));
        expect(message, contains('Electrolyzer'));
        expect(message, contains('Coal Generator'));
      });
    });

    test('a disconnected island needs its own pin', () {
      final b = basic()
        ..pinCount('elec', 1)
        ..add('coal_generator', nodeId: 'island');
      final s = solver.solve(b.build());

      expect(s.status, SolveStatus.underdetermined);
      expect(s.freeNodeIds, ['island']);
      expect(s.nodes['elec']!.count, closeTo(1, 1e-9),
          reason: 'the rest of the graph is still solved');
    });

    test('contradictory pins are reported, not silently averaged', () {
      final b = basic()
        ..pinCount('elec', 1)
        ..pinRate('src_water', sourcePortId, 5000);
      final s = solver.solve(b.build());

      expect(s.status, SolveStatus.inconsistent);
      expect(s.issues.any((i) => i.isError), isTrue);
    });

    test('a mismatched edge is a validation error', () {
      final pipeline = Pipeline(
        id: 'bad',
        name: 'bad',
        nodes: const [
          PipelineNode(id: 'elec', specId: 'electrolyzer'),
          PipelineNode(id: 'gen', specId: 'coal_generator'),
        ],
        edges: const [
          PipelineEdge(
            id: 'e',
            fromNodeId: 'elec',
            fromPortId: 'oxygen',
            toNodeId: 'gen',
            toPortId: 'coal',
          ),
        ],
      );
      final s = solver.solve(pipeline);
      expect(s.status, SolveStatus.invalid);
      expect(s.issues.first.message, contains('oxygen'));
    });

    test('over-committed shares are rejected', () {
      final b = PipelineBuilder(db, name: 'over')
        ..add('electrolyzer', nodeId: 'elec')
        ..addSink('oxygen', nodeId: 'a')
        ..addSink('oxygen', nodeId: 'b')
        ..connect('elec', 'oxygen', 'a', sinkPortId,
            mode: EdgeMode.push, share: 0.8)
        ..connect('elec', 'oxygen', 'b', sinkPortId,
            mode: EdgeMode.push, share: 0.8)
        ..pinCount('elec', 1);
      final s = solver.solve(b.build());
      expect(s.status, SolveStatus.invalid);
    });
  });

  group('venting a surplus', () {
    /// A water geyser feeding electrolyzers that supply a fixed crew — the
    /// question being how much oxygen is left over, not whether the two agree.
    Pipeline geyserAndCrew({Set<String> vented = const {}}) {
      final pipeline = (PipelineBuilder(db, name: 'geyser and crew')
            ..add('water_geyser', nodeId: 'geyser')
            ..add('electrolyzer', nodeId: 'elec')
            ..add('duplicant', nodeId: 'dupes')
            ..addSink('hydrogen')
            ..connectItem('geyser', 'elec', 'water')
            ..connectItem('elec', 'dupes', 'oxygen')
            ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
            ..pinCount('geyser', 1))
          .build();
      return pipeline.copyWith(
        nodes: [
          for (final n in pipeline.nodes)
            if (n.id == 'elec') n.copyWith(ventedPorts: vented) else n,
        ],
        pins: [
          ...pipeline.pins,
          const BuildingCountPin(nodeId: 'dupes', count: 12),
        ],
      );
    }

    test('without venting, two pins look like a contradiction', () {
      final solution = solver.solve(geyserAndCrew());
      expect(solution.status, SolveStatus.inconsistent);
      // And it says what to do about it.
      expect(
        solution.issues.map((i) => i.message).join('\n'),
        contains('venting'),
      );
    });

    test('venting the port turns it into a question about the leftover', () {
      final solution = geyserAndCrew(vented: {'oxygen'});
      final result = solver.solve(solution);

      expect(result.status, SolveStatus.solved);
      // One geyser runs 1.8 Electrolyzers, making 1598.4 g/s of oxygen; twelve
      // dupes breathe 1200 of it.
      expect(result.nodes['elec']!.count, closeTo(1.8, 1e-9));
      expect(result.nodes['dupes']!.count, closeTo(12, 1e-9));
      expect(result.externalOutputs['oxygen'], closeTo(1.8 * 888 - 1200, 1e-6));
    });

    test('venting only affects the port it is asked about', () {
      final result = solver.solve(geyserAndCrew(vented: {'oxygen'}));
      // The hydrogen still goes exactly where it is pulled.
      for (final balance in result.portBalances) {
        if (balance.ref.portId == 'hydrogen') {
          expect(balance.unlinkedRate, closeTo(0, 1e-6));
        }
      }
    });

    test('venting an unconnected port changes nothing', () {
      final base = (PipelineBuilder(db, name: 'lone')
            ..add('electrolyzer', nodeId: 'elec')
            ..pinCount('elec', 1))
          .build();
      final vented = base.copyWith(
        nodes: [
          for (final n in base.nodes) n.copyWith(ventedPorts: {'oxygen'}),
        ],
      );

      expect(solver.solve(vented).externalOutputs['oxygen'],
          closeTo(solver.solve(base).externalOutputs['oxygen']!, 1e-9));
    });

    test('vents survive a JSON round trip', () {
      const node = PipelineNode(
        id: 'elec',
        specId: 'electrolyzer',
        ventedPorts: {'oxygen', 'hydrogen'},
      );
      expect(PipelineNode.fromJson(node.toJson()).ventedPorts,
          {'oxygen', 'hydrogen'});
    });
  });

  group('output scaling', () {
    /// One water geyser feeding electrolyzers, at whatever activity you assume.
    PipelineSolution solveGeyser(double activeFraction) {
      final scale = GeyserActivity.scaleFor(activeFraction);
      final b = PipelineBuilder(db, name: 'geyser fed')
        ..add('water_geyser', nodeId: 'geyser')
        ..add('electrolyzer', nodeId: 'elec')
        ..addSink('oxygen')
        ..addSink('hydrogen')
        ..connectItem('geyser', 'elec', 'water')
        ..connectItem('elec', 'sink_oxygen', 'oxygen')
        ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
        ..pinCount('geyser', 1);
      final pipeline = b.build();
      return solver.solve(pipeline.copyWith(
        nodes: [
          for (final n in pipeline.nodes)
            if (n.id == 'geyser') n.copyWith(outputScale: scale) else n,
        ],
      ));
    }

    test('the shipped rate is the typical roll', () {
      final typical = solveGeyser(GeyserActivity.typicalActiveFraction);
      expect(typical.nodes['elec']!.count, closeTo(1.8, 1e-9));
    });

    test('a dull geyser supports proportionally less', () {
      final worst = solveGeyser(GeyserActivity.minimumActiveFraction);
      // 40 % active against a typical 60 % is two thirds of the supply.
      expect(worst.nodes['elec']!.count, closeTo(1.8 * 2 / 3, 1e-9));
      expect(worst.status, SolveStatus.solved);
    });

    test('a lucky geyser supports more', () {
      final best = solveGeyser(GeyserActivity.maximumActiveFraction);
      expect(best.nodes['elec']!.count, closeTo(1.8 * 4 / 3, 1e-9));
    });

    test('scaling output leaves what a node consumes alone', () {
      final b = PipelineBuilder(db, name: 'scaled consumer')
        ..add('electrolyzer', nodeId: 'elec')
        ..pinCount('elec', 1);
      final pipeline = b.build();
      final solution = solver.solve(pipeline.copyWith(
        nodes: [
          for (final n in pipeline.nodes) n.copyWith(outputScale: 0.5),
        ],
      ));

      expect(solution.externalInputs['water'], closeTo(1000, 1e-9),
          reason: 'it still drinks a full kilogram');
      expect(solution.externalOutputs['oxygen'], closeTo(444, 1e-9),
          reason: 'but makes half the oxygen');
    });

    test('a pinned rate accounts for the scale', () {
      // "This geyser gives me 1200 g/s" on a two-thirds geyser means it is
      // running at one whole geyser's worth.
      final b = PipelineBuilder(db, name: 'pinned scaled')
        ..add('water_geyser', nodeId: 'geyser')
        ..pinRate('geyser', 'water', 1200);
      final pipeline = b.build();
      final solution = solver.solve(pipeline.copyWith(
        nodes: [
          for (final n in pipeline.nodes) n.copyWith(outputScale: 2 / 3),
        ],
      ));

      expect(solution.nodes['geyser']!.count, closeTo(1, 1e-9));
    });

    test('scale survives a JSON round trip', () {
      final node = const PipelineNode(id: 'g', specId: 'water_geyser')
          .copyWith(outputScale: 0.75);
      expect(PipelineNode.fromJson(node.toJson()).outputScale, 0.75);
    });
  });

  group('floor space', () {
    test('a build reports the tiles it needs', () {
      final b = basic()..pinCount('elec', 3);
      final solution = solver.solve(b.build());

      // An Electrolyzer is 2×2, and you build three whole ones.
      expect(solution.nodes['elec']!.totalFootprintTiles, 12);
      expect(solution.totalFootprintTiles, 12,
          reason: 'the supply and output nodes are not things you build');
    });

    test('a fraction of a building still takes a whole one is worth of floor',
        () {
      final solution = solver.solve((basic()..pinCount('elec', 2.1)).build());
      expect(solution.nodes['elec']!.wholeCount, 3);
      expect(solution.nodes['elec']!.totalFootprintTiles, 12);
    });

    test('several buildings add up', () {
      final b = PipelineBuilder(db, name: 'roomy')
        ..add('electrolyzer', nodeId: 'elec')
        ..add('oil_refinery', nodeId: 'refinery')
        ..pinCount('elec', 1)
        ..pinCount('refinery', 1);
      final solution = solver.solve(b.build());

      // 2×2 plus 3×4.
      expect(solution.totalFootprintTiles, 4 + 12);
    });

    test('a critter takes no floor of its own', () {
      final b = PipelineBuilder(db, name: 'ranch')
        ..add('hatch', nodeId: 'hatches')
        ..pinCount('hatches', 8);
      expect(solver.solve(b.build()).totalFootprintTiles, 0,
          reason: 'a Hatch occupies a stable, counted where the stable is');
    });
  });

  group('presentation helpers', () {
    test('uptime turns effective units into buildings to place', () {
      final b = PipelineBuilder(db, name: 'duty cycle')
        ..add('electrolyzer', nodeId: 'elec', uptime: 0.5)
        ..pinCount('elec', 3);
      final s = solver.solve(b.build());

      expect(s.nodes['elec']!.physicalCount, closeTo(6, 1e-9));
      expect(s.nodes['elec']!.wholeCount, 6);
    });

    test('fractional counts round up and report idle capacity', () {
      final s = solver.solve((basic()..pinCount('elec', 2.4)).build());
      final elec = s.nodes['elec']!;
      expect(elec.wholeCount, 3);
      expect(elec.utilisation, closeTo(0.8, 1e-9));
    });

    test('the text report mentions the key numbers', () {
      final s = solver.solve((basic()..pinCount('elec', 3)).build());
      final text = formatSolution(s, db);
      expect(text, contains('Electrolyzer'));
      expect(text, contains('Water'));
      expect(text, contains('Power'));
    });
  });

  group('persistence', () {
    test('a pipeline round-trips through JSON and solves the same', () {
      final original = (basic()..pinCount('elec', 3)).build();
      final restored =
          Pipeline.fromJsonString(jsonEncode(original.toJson()));

      final a = solver.solve(original);
      final b = solver.solve(restored);
      expect(b.status, a.status);
      for (final id in a.nodes.keys) {
        expect(b.nodes[id]!.count, closeTo(a.nodes[id]!.count, 1e-9));
      }
    });
  });

  group('wild farming', () {
    test('a wild plant feeds a quarter of the critters', () {
      final db = loadDefaultDatabase();
      final solver = PipelineSolver(db);

      double plantsFor(String plant) {
        final pipeline = (PipelineBuilder(db, name: 'grazing')
              ..add(plant, nodeId: 'plants')
              ..add('glo_squid', nodeId: 'squid')
              ..connectItem('plants', 'squid', 'tublia_growth')
              ..pinCount('squid', 1))
            .build();
        final solution = solver.solve(pipeline);
        expect(solution.status, SolveStatus.solved);
        return solution.nodes['plants']!.count;
      }

      // The wiki's own numbers: one Glo Squid needs two farmed Tublia or eight
      // wild ones, because a wild plant ripens at a quarter of the speed.
      expect(plantsFor('tublia_grazed_wild'),
          closeTo(plantsFor('tublia_grazed') * 4, 1e-6));
    });
  });

  group('wild ranching', () {
    test('the same coal, none of the Duplicant time, a tenth of the meat', () {
      PipelineSolution ranch(String critter) {
        final pipeline = (PipelineBuilder(db, name: 'ranch')
              ..add(critter, nodeId: 'hatches')
              ..addSource('sedimentary_rock')
              ..addSink('coal')
              ..connectItem('src_sedimentary_rock', 'hatches', 'sedimentary_rock')
              ..connectItem('hatches', 'sink_coal', 'coal')
              ..pinRate('sink_coal', sinkPortId, 1))
            .build();
        return solver.solve(pipeline);
      }

      final tame = ranch('hatch');
      final wild = ranch('hatch_wild');

      expect(tame.status, SolveStatus.solved);
      expect(wild.status, SolveStatus.solved);
      // Coal comes from eating, and grooming does not change what a Hatch eats,
      // so the two ranches are the same size.
      expect(wild.nodes['hatches']!.count,
          closeTo(tame.nodes['hatches']!.count, 1e-6));
      // The whole point: nobody tends it.
      expect(tame.dupeLabourSecondsPerCycle, greaterThan(0));
      expect(wild.dupeLabourSecondsPerCycle, 0);
      // And the whole cost: a tenth of the eggs, so a tenth of the meat.
      double eggs(PipelineSolution s) {
        final node = s.nodes['hatches']!;
        return node.count *
            db
                .processOrThrow(node.specId)
                .outputs
                .firstWhere((p) => p.itemId == 'egg')
                .ratePerSecond;
      }

      expect(eggs(wild), closeTo(eggs(tame) / 10, 1e-9));
    });
  });

  group('an amount below nothing', () {
    Pipeline pinnedTo(double count) => (PipelineBuilder(db, name: 'minus')
          ..addSource('water')
          ..add('electrolyzer', nodeId: 'elec')
          ..connectItem('src_water', 'elec', 'water')
          ..pinCount('elec', count))
        .build();

    test('is refused where it was typed, not where it lands', () {
      final solution = PipelineSolver(db).solve(pinnedTo(-5));
      expect(solution.status, SolveStatus.invalid);

      final issue = solution.issues.singleWhere((i) => i.isError);
      expect(issue.nodeId, 'elec', reason: 'the node somebody typed it on');
      expect(issue.message, contains('below nothing'));
      // What it used to say: two errors, about the node and its supply, both
      // advising a look at the edge shares — which is the right advice for
      // the other way a count goes negative, and no help at all for a minus
      // sign.
      expect(solution.issues.where((i) => i.message.contains('edge shares')),
          isEmpty);
    });

    test('and nothing is still a build', () {
      // Zero is a real answer: a build of no Electrolyzers eats no water, and
      // saying so beats refusing to draw it while somebody clears the field.
      final solution = PipelineSolver(db).solve(pinnedTo(0));
      expect(solution.status, SolveStatus.solved);
      expect(solution.nodes['src_water']!.count, 0);
    });

    test('and a rate below nothing goes the same way', () {
      final pipeline = (PipelineBuilder(db, name: 'minus')
            ..addSource('water')
            ..add('electrolyzer', nodeId: 'elec')
            ..connectItem('src_water', 'elec', 'water')
            ..pinRate('src_water', sourcePortId, -1000))
          .build();
      final solution = PipelineSolver(db).solve(pipeline);

      expect(solution.status, SolveStatus.invalid);
      expect(solution.issues.singleWhere((i) => i.isError).message,
          contains('below nothing'));
    });
  });
  group('zero has no sign', () {
    test('an over-constrained build reports nothing, not minus nothing', () {
      // Elimination lands on -0.0 here, and every screen that prints a count
      // then said "-0.00 ×" — which reads as a quantity pointing backwards.
      final b = PipelineBuilder(db, name: 'self-powered')
        ..addSource('water')
        ..add('electrolyzer', nodeId: 'elec')
        ..add('hydrogen_generator', nodeId: 'hgen')
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'hgen', 'hydrogen')
        ..connect('hgen', 'power_out', 'elec', 'power_in');
      final s = solver.solve(b.build());

      for (final node in s.nodes.values) {
        expect(node.count.toStringAsFixed(2), isNot(startsWith('-')),
            reason: node.nodeId);
      }
      for (final flow in s.edgeFlows.values) {
        expect(flow.toStringAsFixed(2), isNot(startsWith('-')));
      }
    });

    test('and a trickle too small to see is not a flow going backwards', () {
      expect(Unit.gramsPerSecond.format(-0.004, precision: 1), '0.0 g/s');
      expect(Unit.watts.format(-0.0), '0.00 W');
      // A real negative still says so: surplus and deficit are the whole point
      // of the power line in the bottom bar.
      expect(Unit.watts.format(-216), '-216.00 W');
    });
  });

  group('two wires into one port', () {
    // Reported twice from one build. A Petroleum Generator's own polluted
    // water goes back to the Arbor Trees that feed it, and a supply is added
    // alongside to make up the difference — which is how anybody would draw
    // it, and which the app read as "half each".
    test('split a demand evenly, which is a guess', () {
      final p = (PipelineBuilder(db, name: 'top up')
            ..addSource('polluted_water', nodeId: 'fixed')
            ..addSource('polluted_water', nodeId: 'topup')
            ..add('arbor_tree', nodeId: 'tree')
            ..connectItem('fixed', 'tree', 'polluted_water')
            ..connectItem('topup', 'tree', 'polluted_water')
            ..pinCount('tree', 7.2)
            ..pinRate('fixed', 'out', 750))
          .build();
      final s = solver.solve(p);

      // 7.2 trees drink 840 g/s. One wire brings 750 and the other should
      // bring 90 — but each is told to carry half of 840, and 750 is not 420.
      expect(s.status, SolveStatus.inconsistent);
      final said = s.issues.map((i) => i.message).join('\n');
      expect(said, contains('2 wires bring polluted water into the Arbor Tree'));
      expect(said, contains('the producer'));
    });

    test('and say so exactly when each hands over what it makes', () {
      final p = (PipelineBuilder(db, name: 'top up')
            ..addSource('polluted_water', nodeId: 'fixed')
            ..addSource('polluted_water', nodeId: 'topup')
            ..add('arbor_tree', nodeId: 'tree')
            ..connectItem('fixed', 'tree', 'polluted_water', mode: EdgeMode.push)
            ..connectItem('topup', 'tree', 'polluted_water', mode: EdgeMode.push)
            ..pinCount('tree', 7.2)
            ..pinRate('fixed', 'out', 750))
          .build();
      final s = solver.solve(p);

      expect(s.status, SolveStatus.solved);
      expect(s.nodes['fixed']!.count, closeTo(750, 1e-6));
      // Not to the microgram: the tree's 70 kg a cycle is stored as
      // 116.666667 g/s, and seven of them carry that rounding into the
      // answer.
      expect(s.nodes['topup']!.count, closeTo(90, 1e-3));
    });

    test('and stay quiet when somebody has already said how to divide it', () {
      final p = (PipelineBuilder(db, name: 'told')
            ..addSource('polluted_water', nodeId: 'fixed')
            ..addSource('polluted_water', nodeId: 'topup')
            ..add('arbor_tree', nodeId: 'tree')
            ..connectItem('fixed', 'tree', 'polluted_water', share: 750 / 840)
            ..connectItem('topup', 'tree', 'polluted_water', share: 90 / 840)
            ..pinCount('tree', 7.2))
          .build();
      final s = solver.solve(p);

      expect(s.status, SolveStatus.solved);
      expect(s.issues.map((i) => i.message).join(), isNot(contains('2 wires')));
    });
  });

  group('a vented port', () {
    // Venting an output drops its balance equation, which is how the surplus
    // is allowed to go to waste. It used to drop the equation altogether,
    // which also allowed the *shortfall* to be conjured — found in a build
    // sent in from the Discord, where three wires drew more sulfur out of a
    // Marine Drill than it makes and every count downstream was 4.6 %
    // optimistic under a clean "solved".
    // Push shares over 100 % are rejected before the solve, so this is the
    // shape that gets through: two producer-driven wires taking their share,
    // and a third consumer-driven one helping itself on top.
    Pipeline drawing(double share) {
      final base = (PipelineBuilder(db, name: 'sulfur')
            ..add('marine_drill', nodeId: 'drill')
            ..add('tublia', nodeId: 'a')
            ..add('tublia', nodeId: 'b')
            ..add('gum_palm', nodeId: 'palm')
            ..connectItem('drill', 'a', 'sulfur',
                mode: EdgeMode.push, share: share)
            ..connectItem('drill', 'b', 'sulfur',
                mode: EdgeMode.push, share: share)
            ..connectItem('drill', 'palm', 'sulfur')
            ..pinCount('palm', 3)
            ..pinCount('drill', 6))
          .build();
      return base.copyWith(nodes: [
        for (final n in base.nodes)
          if (n.id == 'drill') n.copyWith(ventedPorts: {'sulfur'}) else n,
      ]);
    }

    test('lets what is spare go to waste', () {
      final s = solver.solve(drawing(0.4));
      expect(s.status, SolveStatus.solved);
    });

    test('and says so when more is drawn than made', () {
      final s = solver.solve(drawing(0.5));

      expect(s.status, SolveStatus.inconsistent);
      expect(
        s.issues.map((i) => i.message).join(),
        contains('More is being drawn from the Marine Drill\u2019s sulfur'),
      );
    });
  });

}