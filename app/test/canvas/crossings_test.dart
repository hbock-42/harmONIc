import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/auto_layout.dart';
import 'package:oni_pipeline/canvas/geometry.dart';

import '../support/harness.dart';

/// How many pairs of wires actually cross, measured on the placed nodes.
///
/// The layout counts crossings internally to score its own sweeps, but it does
/// so over its own expanded graph. This counts what a person would see: a
/// straight line from each output edge to each input edge, and every pair of
/// them that meets in the middle.
int crossings(Pipeline pipeline, Map<String, Offset> at) {
  Offset out(String id) {
    final node = pipeline.nodeOrThrow(id);
    final size = NodeLayout.sizeOf(testDatabase.processOrThrow(node.specId));
    return at[id]! + Offset(size.width, size.height / 2);
  }
  Offset into(String id) {
    final node = pipeline.nodeOrThrow(id);
    final size = NodeLayout.sizeOf(testDatabase.processOrThrow(node.specId));
    return at[id]! + Offset(0, size.height / 2);
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
      if ({a.fromNodeId, a.toNodeId}
          .intersection({b.fromNodeId, b.toNodeId}).isNotEmpty) {
        continue;
      }
      if (intersect(out(a.fromNodeId), into(a.toNodeId), out(b.fromNodeId),
          into(b.toNodeId))) {
        total++;
      }
    }
  }
  return total;
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
    // caught: 2 649 crossings without them against 2 248 with.
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

    expect(graphs, 427, reason: 'the corpus itself changed, so the score below '
        'is no longer comparable — re-measure before moving it');
    expect(total, lessThanOrEqualTo(2248));
  });
}
