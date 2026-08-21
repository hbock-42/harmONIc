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
      expect(
        s.issues.map((i) => i.message).join('\n'),
        contains('connect an output node'),
      );
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
}
