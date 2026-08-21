import '../graph/pipeline.dart';
import '../model/game_database.dart';
import '../model/process_spec.dart';
import 'solution.dart';

/// A machine you only half need simply idles: three Electrolyzers running 83 %
/// of the time make exactly the oxygen 2.5 of them would. A Hatch does not idle.
/// Thirteen Hatches eat like thirteen Hatches whether you wanted 12.4 or not,
/// and the same goes for a plant in the ground and a Duplicant in the base.
const Set<ProcessKind> _cannotIdle = {
  ProcessKind.critter,
  ProcessKind.plant,
  ProcessKind.duplicant,
};

/// What one item does differently once the build is real.
class AsBuiltDrift {
  const AsBuiltDrift({
    required this.itemId,
    required this.exactNet,
    required this.builtNet,
  });

  final String itemId;

  /// Produced minus consumed at the exact fractional ratio.
  final double exactNet;

  /// The same, with everything that cannot idle rounded up to whole.
  final double builtNet;

  /// Positive = the real build makes more of this than the ratio said (surplus
  /// to store or vent). Negative = it eats more, and something must supply it.
  double get change => builtNet - exactNet;
}

/// The build as you would actually place it, rather than as the ratio wants it.
class AsBuiltReport {
  const AsBuiltReport({
    required this.counts,
    required this.roundedUp,
    required this.drifts,
  });

  /// Node id → the count that actually runs: whole for anything that cannot
  /// idle, unchanged for machines, which simply run less of the time.
  final Map<String, double> counts;

  /// The nodes that had to be rounded up, and by how much.
  final Map<String, double> roundedUp;

  /// Items whose totals moved because of that rounding, worst first.
  final List<AsBuiltDrift> drifts;

  bool get isExact => roundedUp.isEmpty;
}

/// Re-report a solved pipeline with whole critters, plants and Duplicants.
///
/// This does not re-solve. Rounding a count up cannot ripple back through the
/// graph without inventing a second answer to a question the user already
/// answered by pinning; what it does is say honestly what the extra bodies eat
/// and produce, and leave the choice of what to do about it where it belongs.
AsBuiltReport asBuilt(
  Pipeline pipeline,
  GameDatabase database,
  PipelineSolution solution,
) {
  final counts = <String, double>{};
  final roundedUp = <String, double>{};

  for (final node in pipeline.nodes) {
    final result = solution.nodes[node.id];
    if (result == null) continue;
    if (result.isBoundary || !_cannotIdle.contains(result.kind)) {
      counts[node.id] = result.count;
      continue;
    }
    final whole = result.wholeCount.toDouble();
    counts[node.id] = whole;
    if (whole - result.count > 1e-9) roundedUp[node.id] = whole - result.count;
  }

  Map<String, double> totals(Map<String, double> scale) {
    final net = <String, double>{};
    for (final node in pipeline.nodes) {
      final spec = database.process(node.specId);
      final count = scale[node.id];
      if (spec == null || count == null) continue;
      if (solution.nodes[node.id]?.isBoundary ?? true) continue;
      for (final port in spec.ports) {
        final rate = port.isOutput
            ? port.ratePerSecond * node.outputScale
            : port.ratePerSecond;
        net[port.itemId] = (net[port.itemId] ?? 0) +
            (port.isOutput ? rate : -rate) * count;
      }
    }
    return net;
  }

  final exact = totals({
    for (final entry in solution.nodes.entries) entry.key: entry.value.count,
  });
  final built = totals(counts);

  final drifts = <AsBuiltDrift>[];
  for (final itemId in {...exact.keys, ...built.keys}) {
    final drift = AsBuiltDrift(
      itemId: itemId,
      exactNet: exact[itemId] ?? 0,
      builtNet: built[itemId] ?? 0,
    );
    if (drift.change.abs() > 1e-9) drifts.add(drift);
  }
  drifts.sort((a, b) => b.change.abs().compareTo(a.change.abs()));

  return AsBuiltReport(counts: counts, roundedUp: roundedUp, drifts: drifts);
}
