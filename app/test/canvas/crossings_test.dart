import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/auto_layout.dart';
import 'package:oni_pipeline/canvas/geometry.dart';

import '../support/harness.dart';

/// How many pairs of wires actually cross, measured on the placed nodes.
///
/// The layout counts crossings internally to score its own sweeps, but it does
/// so over its own expanded graph. This counts what a person would see: a
/// straight line between the two port dots a wire actually joins, and every
/// pair of them that meets in the middle.
///
/// It used to run those lines between the middles of the two nodes, which made
/// it blind to exactly the crossings a person complains about — two wires into
/// the same node, arriving at different rows, in the wrong order.
int crossings(Pipeline pipeline, Map<String, Offset> at) {
  Offset endOf(String nodeId, String portId) {
    final node = pipeline.nodeOrThrow(nodeId);
    final spec = testDatabase.processOrThrow(node.specId);
    return at[nodeId]! + NodeLayout.portOffset(spec, portId);
  }
  double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  bool intersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    final d1 = cross(p2 - p1, p3 - p1);
    final d2 = cross(p2 - p1, p4 - p1);
    final d3 = cross(p4 - p3, p1 - p3);
    final d4 = cross(p4 - p3, p2 - p3);
    return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0));
  }

  var total = 0;
  final edges = pipeline.edges;
  for (var i = 0; i < edges.length; i++) {
    for (var j = i + 1; j < edges.length; j++) {
      final a = edges[i];
      final b = edges[j];
      // Two wires sharing a *port* meet there by definition; two wires into
      // different ports of the same node do not, and those are precisely the
      // crossings a person notices. Skipping every edge pair that shared a
      // node made this blind to them.
      final ends = <String>{
        '${a.fromNodeId}.${a.fromPortId}',
        '${a.toNodeId}.${a.toPortId}',
      };
      if (ends.contains('${b.fromNodeId}.${b.fromPortId}') ||
          ends.contains('${b.toNodeId}.${b.toPortId}')) {
        continue;
      }
      if (intersect(
          endOf(a.fromNodeId, a.fromPortId),
          endOf(a.toNodeId, a.toPortId),
          endOf(b.fromNodeId, b.fromPortId),
          endOf(b.toNodeId, b.toPortId))) {
        total++;
      }
    }
  }
  return total;
}

/// How far a build's wires stray from flat, in pixels of vertical drop summed
/// over every wire.
///
/// A crossing count says whether the picture is tangled; this says whether it
/// is tidy. Both matter, and a layout can trade one for the other, so both are
/// measured.
double sag(Pipeline pipeline, Map<String, Offset> at) {
  Offset endOf(String nodeId, String portId) {
    final node = pipeline.nodeOrThrow(nodeId);
    final spec = testDatabase.processOrThrow(node.specId);
    return at[nodeId]! + NodeLayout.portOffset(spec, portId);
  }

  var total = 0.0;
  for (final edge in pipeline.edges) {
    total += (endOf(edge.fromNodeId, edge.fromPortId).dy -
            endOf(edge.toNodeId, edge.toPortId).dy)
        .abs();
  }
  return total;
}

/// How many wires run across a node they have nothing to do with.
///
/// The measure the other two cannot see. A wire passing straight through the
/// middle of a card is not a crossing and adds no sag, and it is the thing that
/// makes a picture unreadable — you cannot tell where it goes.
int wiresOverNodes(Pipeline pipeline, Map<String, Offset> at) {
  Offset endOf(String nodeId, String portId) {
    final node = pipeline.nodeOrThrow(nodeId);
    final spec = testDatabase.processOrThrow(node.specId);
    return at[nodeId]! + NodeLayout.portOffset(spec, portId);
  }

  var total = 0;
  for (final edge in pipeline.edges) {
    final a = endOf(edge.fromNodeId, edge.fromPortId);
    final b = endOf(edge.toNodeId, edge.toPortId);
    for (final node in pipeline.nodes) {
      if (node.id == edge.fromNodeId || node.id == edge.toNodeId) continue;
      final box = at[node.id]! &
          NodeLayout.sizeOf(testDatabase.processOrThrow(node.specId));
      // Sampled along the wire rather than solved: a straight line is a fair
      // stand-in for the curve actually drawn, and twenty points is plenty at
      // this scale.
      for (var i = 1; i < 20; i++) {
        if (box.contains(Offset.lerp(a, b, i / 20)!)) {
          total++;
          break;
        }
      }
    }
  }
  return total;
}

/// Four hundred-odd random builds, the same ones every run.
///
/// Was written inline inside the sag measurement and is now shared, because
/// the thing that most wanted checking against every graph -- that no card
/// ends up on top of another -- had only ever been asked of one hand-made one.
List<Pipeline> corpus() {
  final specs = [
    for (final id in [
      'electrolyzer', 'hydrogen_generator', 'coal_generator', 'water_sieve',
      'deodorizer', 'algae_distiller', 'oxygen_diffuser', 'carbon_skimmer',
      'metal_refinery', 'rock_crusher_sand', 'oil_refinery', 'polymer_press',
      'petroleum_generator', 'ethanol_distiller', 'compost',
      'fertilizer_synthesizer', 'duplicant', 'hatch', 'mealwood',
      'sleet_wheat',
    ])
      testDatabase.processOrThrow(id),
  ];
  var seed = 12345;
  int next(int bound) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed % bound;
  }

  final built = <Pipeline>[];
  for (var trial = 0; trial < 600; trial++) {
    final chosen = <ProcessSpec>[];
    final size = 6 + next(9);
    for (var i = 0; i < size; i++) {
      chosen.add(specs[next(specs.length)]);
    }
    final b = PipelineBuilder(testDatabase, name: 'random');
    final ids = <String>[];
    for (var i = 0; i < chosen.length; i++) {
      final id = 'n$i';
      b.add(chosen[i].id, nodeId: id);
      ids.add(id);
    }
    var edges = 0;
    for (var i = 0; i < chosen.length; i++) {
      for (var j = i + 1; j < chosen.length; j++) {
        final shared = chosen[i].outputs
            .map((p) => p.itemId)
            .toSet()
            .intersection(chosen[j].inputs.map((p) => p.itemId).toSet());
        if (shared.isEmpty) continue;
        try {
          b.connectItem(ids[i], ids[j], shared.first);
          edges++;
        } catch (_) {
          continue;
        }
      }
    }
    if (edges < 4) continue;
    built.add(b.build());
  }
  return built;
}

void main() {
  Map<String, Offset> layoutOf(Pipeline pipeline) =>
      AutoLayout(pipeline: pipeline, database: testDatabase).positions();

  test('a long wire is ordered against what it passes, not ignored', () {
    // The generator feeds the Electrolyzer and the power output three columns
    // away, so that second wire crosses everything between them unless the
    // columns it passes through make room for it.
    final pipeline = (PipelineBuilder(testDatabase, name: 'tangled')
          ..addSource('water')
          ..addSource('salt_water')
          ..add('coal_generator', nodeId: 'coal')
          ..add('electrolyzer', nodeId: 'elec')
          ..add('hydrogen_generator', nodeId: 'hgen')
          ..add('flue_coral', nodeId: 'coral')
          ..add('duplicant', nodeId: 'dupes')
          ..addSink('power')
          ..addSink('oxygen')
          ..addSink('carbon_dioxide')
          ..connectItem('src_water', 'elec', 'water')
          ..connectItem('coal', 'elec', 'power')
          ..connectItem('elec', 'hgen', 'hydrogen')
          ..connectItem('elec', 'sink_oxygen', 'oxygen')
          ..connectItem('hgen', 'sink_power', 'power')
          ..connectItem('coal', 'sink_power', 'power')
          ..connectItem('src_salt_water', 'coral', 'salt_water')
          ..connectItem('coral', 'dupes', 'oxygen')
          ..connectItem('dupes', 'sink_carbon_dioxide', 'carbon_dioxide'))
        .build();

    expect(crossings(pipeline, layoutOf(pipeline)), lessThanOrEqualTo(1));
  });

  test('the layout is the same every time it is asked', () {
    final pipeline = (PipelineBuilder(testDatabase, name: 'stable')
          ..addSource('water')
          ..add('electrolyzer', nodeId: 'elec')
          ..add('hydrogen_generator', nodeId: 'hgen')
          ..connectItem('src_water', 'elec', 'water')
          ..connectItem('elec', 'hgen', 'hydrogen'))
        .build();

    expect(layoutOf(pipeline), layoutOf(pipeline));
  });

  test('crossings over a corpus of graphs stay where they were put', () {
    // A pseudo-random corpus of graphs, scored for crossings. The absolute
    // number means nothing on its own; it is a ratchet, and what it watches is
    // the layout. Without dummy vertices for edges that skip a column —
    // Sugiyama's third phase, which this had been missing — the same corpus
    // scores worse, and this is where a change that makes pictures worse gets
    // caught.
    //
    // The figure moved for reasons that were not the layout getting worse. It counted wires between the middles of nodes, which cannot see
    // two wires arriving at different rows of the same node in the wrong
    // order — the commonest crossing there is — and it skipped every pair of
    // edges that shared a node, which is exactly that case. Counted honestly,
    // port to port: 2 993 before the layout learned about ports, 2 683 after,
    // 2 431 once nodes were allowed to slide up and down to meet their wires —
    // straightening turns out to untangle as well, because a wire that runs
    // flat crosses less on the way — and 2 329 once the lanes a wire needs to
    // pass a column were kept all the way through the placing.
    //
    // The cast is written out rather than taken from the database, because a
    // corpus drawn from "everything there is" moves every time the database
    // grows: it went 364 graphs, then 512, then 460, then 594 across four
    // unrelated data commits, and each time both figures had to be measured
    // again to mean anything. These twenty recipes are enough to tangle, and
    // they hold still. A name disappearing from the database fails this test,
    // which is the right way round.
    const cast = <String>[
      'electrolyzer', 'hydrogen_generator', 'coal_generator', 'water_sieve',
      'deodorizer', 'algae_distiller', 'oxygen_diffuser', 'carbon_skimmer',
      'metal_refinery', 'rock_crusher_sand', 'oil_refinery', 'polymer_press',
      'petroleum_generator', 'ethanol_distiller', 'compost',
      'fertilizer_synthesizer', 'duplicant', 'hatch', 'mealwood',
      'sleet_wheat',
    ];
    final specs = [for (final id in cast) testDatabase.processOrThrow(id)];
    var seed = 12345;
    int next(int bound) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed % bound;
    }

    var total = 0;
    var graphs = 0;
    for (var trial = 0; trial < 600; trial++) {
      final chosen = <ProcessSpec>[];
      final size = 6 + next(9);
      for (var i = 0; i < size; i++) {
        chosen.add(specs[next(specs.length)]);
      }
      final b = PipelineBuilder(testDatabase, name: 'random');
      final ids = <String>[];
      for (var i = 0; i < chosen.length; i++) {
        final id = 'n$i';
        b.add(chosen[i].id, nodeId: id);
        ids.add(id);
      }
      var edges = 0;
      for (var i = 0; i < chosen.length; i++) {
        for (var j = i + 1; j < chosen.length; j++) {
          final shared = chosen[i].outputs
              .map((p) => p.itemId)
              .toSet()
              .intersection(chosen[j].inputs.map((p) => p.itemId).toSet());
          if (shared.isEmpty) continue;
          try {
            b.connectItem(ids[i], ids[j], shared.first);
            edges++;
          } catch (_) {
            continue;
          }
        }
      }
      if (edges < 4) continue;
      final pipeline = b.build();
      total += crossings(pipeline, layoutOf(pipeline));
      graphs++;
    }

    expect(graphs, 424, reason: 'the corpus itself changed, so the score below '
        'is no longer comparable — re-measure before moving it');
    expect(total, lessThanOrEqualTo(2329));
  });

  group('ports decide the order within a column', () {
    /// The cooling loop, which a person rearranges into a crossing-free
    /// picture in about ten seconds and the layout used to make a mess of.
    Pipeline coolingLoop() =>
        pipelineTemplates.firstWhere((t) => t.id == 'cooling_loop').build(testDatabase);

    test('the cooling loop comes out with nothing crossing', () {
      final pipeline = coolingLoop();
      expect(crossings(pipeline, layoutOf(pipeline)), 0);
    });

    test('two supplies feeding one node stack the way its ports do', () {
      // The Aquatuner takes water at its first port row and heat at its
      // second, so the water supply belongs above the heat supply. Both feed
      // the same node, so with nodes treated as points they scored identically
      // and fell back on the order they were created in — which was heat
      // first, and a crossed pair of wires.
      final pipeline = coolingLoop();
      final at = layoutOf(pipeline);

      final water = at['src_water']!;
      final heat = at['src_heat']!;
      expect(water.dy, lessThan(heat.dy));
    });

    test('a wire passing a column is ordered by where it lands, not by luck',
        () {
      // The steam supply skips the Aquatuner's column entirely and arrives at
      // the turbine's first port row, above the heat the Aquatuner sends it.
      // So the steam has to pass above the Aquatuner, not below it.
      final pipeline = coolingLoop();
      final at = layoutOf(pipeline);

      expect(at['src_steam']!.dy, lessThan(at['tuner']!.dy));
    });
  });

  group('wires that run flat', () {
    /// The reef: coquina and salt water in, oxygen and a fed crew out, with a
    /// long salt-water wire crossing two columns to reach the Flue Coral.
    Pipeline reef() => (PipelineBuilder(testDatabase, name: 'Reef')
          ..addSource('salt_water')
          ..addSource('coquina')
          ..add('aquatic_grooming_station', nodeId: 'station')
          ..add('starnacle_grazed', nodeId: 'plants')
          ..add('beakon_grazing', nodeId: 'fish')
          ..add('flue_coral', nodeId: 'coral')
          ..add('duplicant', nodeId: 'dupes')
          ..connectItem('src_coquina', 'plants', 'coquina')
          ..connectItem('plants', 'fish', 'starnacle_growth')
          ..connectItem('station', 'fish', 'grooming')
          ..connectItem('fish', 'coral', 'lime')
          ..connectItem('src_salt_water', 'coral', 'salt_water')
          ..connectItem('coral', 'dupes', 'oxygen')
          ..pinCount('plants', 2))
        .build();

    test('a node moves to meet the wire coming into it', () {
      final pipeline = reef();
      final at = layoutOf(pipeline);

      // The salt water supply and the Flue Coral it feeds sit three columns
      // apart. Stacked and centred, that wire dropped across the whole
      // picture; now the two ports are within a row of each other.
      final supply = at['src_salt_water']! +
          NodeLayout.portOffset(
              testDatabase.processOrThrow('source:salt_water'), 'out');
      final coral = at['coral']! +
          NodeLayout.portOffset(
              testDatabase.processOrThrow('flue_coral'), 'salt_water');
      expect((supply.dy - coral.dy).abs(), lessThan(NodeLayout.portRowHeight));
    });

    test('and nothing ends up on top of anything else', () {
      final pipeline = reef();
      final at = layoutOf(pipeline);

      for (final a in pipeline.nodes) {
        for (final b in pipeline.nodes) {
          if (a.id == b.id) continue;
          final ra = at[a.id]! &
              NodeLayout.sizeOf(testDatabase.processOrThrow(a.specId));
          final rb = at[b.id]! &
              NodeLayout.sizeOf(testDatabase.processOrThrow(b.specId));
          expect(ra.overlaps(rb), isFalse, reason: '${a.id} sits on ${b.id}');
        }
      }
    });

    test('and that holds across the whole corpus, not just one tidy graph',
        () {
      // This test existed for one hand-made graph and passed all along while
      // real builds came out with cards on top of each other -- two pairs on
      // one that was sent in, four on another. One graph proves the layout can
      // be asked nicely; four hundred prove it cannot be caught out.
      var overlaps = 0;
      var graphs = 0;
      for (final pipeline in corpus()) {
        graphs++;
        final at = layoutOf(pipeline);
        final rects = [
          for (final n in pipeline.nodes)
            if (at[n.id] case final Offset o)
              o & NodeLayout.sizeOf(testDatabase.processOrThrow(n.specId)),
        ];
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            if (rects[i].overlaps(rects[j])) overlaps++;
          }
        }
      }
      expect(graphs, greaterThan(400), reason: 'the corpus is still there');
      expect(overlaps, 0);
    });

    test('the corpus sags less than it did, and tangles no more', () {
      var total = 0.0;
      var through = 0;
      var graphs = 0;
      for (final pipeline in corpus()) {
        final at = layoutOf(pipeline);
        total += sag(pipeline, at);
        through += wiresOverNodes(pipeline, at);
        graphs++;
      }

      // The three measures pull against each other, so all three are pinned.
      // Stacked and centred, with no node ever moving to meet a wire, this
      // corpus sagged 667 650 pixels and ran 1 266 wires across a node that had
      // nothing to do with them. Straightening cut the sag to 567 858 and left
      // the wires-over-nodes exactly where they were.
      //
      // Keeping a lane for every wire that passes a column, and scoring for it,
      // trades the other way: 983 wires over nodes, and more droop. That is the
      // right way round. A wire that sags is untidy; a wire crossing the middle
      // of a card is one you cannot follow at all — and it is the trade a
      // person makes by hand, moving a node down out of the way even though its
      // own wire then has further to fall.
      //
      // 720 102 was the figure while columns were still allowed to overlap
      // themselves, and part of it was bought that way: two cards in the same
      // place make the wires between them perfectly flat. Reported, and true
      // of real builds — two overlapping pairs on one, four on another, every
      // one of them within a column. Separating them costs 12 % more sag and
      // that is simply what it costs; the arrangement it is measured against
      // was never one the app could legally draw.
      expect(graphs, 424);
      expect(through, lessThanOrEqualTo(983));
      expect(total, lessThanOrEqualTo(811177));
    });
  });

  test('a wire passing a column keeps its lane, and its own wire runs flat',
      () {
    // The reef again, and the two things a person fixes by hand in about ten
    // seconds: the grooming wire runs the length of the picture without
    // crossing anything, and the Starnacle sits below it rather than in it.
    final pipeline = (PipelineBuilder(testDatabase, name: 'Reef')
          ..addSource('salt_water')
          ..addSource('coquina')
          ..add('aquatic_grooming_station', nodeId: 'station')
          ..add('starnacle_grazed', nodeId: 'plants')
          ..add('beakon_grazing', nodeId: 'fish')
          ..add('flue_coral', nodeId: 'coral')
          ..add('duplicant', nodeId: 'dupes')
          ..connectItem('src_coquina', 'plants', 'coquina')
          ..connectItem('plants', 'fish', 'starnacle_growth')
          ..connectItem('station', 'fish', 'grooming')
          ..connectItem('fish', 'coral', 'lime')
          ..connectItem('src_salt_water', 'coral', 'salt_water')
          ..connectItem('coral', 'dupes', 'oxygen')
          ..pinCount('plants', 2))
        .build();
    final at = layoutOf(pipeline);

    expect(wiresOverNodes(pipeline, at), 0);
    expect(crossings(pipeline, at), 0);

    // Every wire that can run flat does: coquina into the Starnacle, grooming
    // the length of the build, salt water into the coral, oxygen to the crew.
    // The two that cannot are the ones a person also draws as curves.
    double drop(String fromNode, String fromPort, String toNode, String port) {
      final from = pipeline.nodeOrThrow(fromNode);
      final to = pipeline.nodeOrThrow(toNode);
      final a = at[fromNode]! +
          NodeLayout.portOffset(
              testDatabase.processOrThrow(from.specId), fromPort);
      final b = at[toNode]! +
          NodeLayout.portOffset(testDatabase.processOrThrow(to.specId), port);
      return (a.dy - b.dy).abs();
    }

    expect(drop('station', 'grooming', 'fish', 'grooming'), 0);
    expect(drop('src_coquina', 'out', 'plants', 'coquina'), 0);
    expect(drop('src_salt_water', 'out', 'coral', 'salt_water'), 0);
    expect(drop('coral', 'oxygen', 'dupes', 'oxygen'), 0);
  });
}