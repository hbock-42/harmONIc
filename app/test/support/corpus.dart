import 'package:oni_engine/oni_engine.dart';

import 'harness.dart';

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
