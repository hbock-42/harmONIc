import '../graph/pipeline.dart';
import '../graph/validation.dart';
import '../model/game_database.dart';
import '../model/port.dart';
import '../model/process_spec.dart';

enum SolveStatus {
  /// Exactly one solution; the numbers are trustworthy.
  solved,

  /// Consistent, but the graph needs another pin. Free nodes were set to zero.
  underdetermined,

  /// The pins contradict each other.
  inconsistent,

  /// The pipeline itself is malformed; nothing was solved.
  invalid,
}

/// What one node ended up as.
class NodeResult {
  const NodeResult({
    required this.nodeId,
    required this.specId,
    required this.kind,
    required this.count,
    required this.uptime,
    required this.powerWatts,
    required this.heatKdtu,
    required this.dupeLabourSecondsPerCycle,
    this.footprintTiles = 0,
  });

  final String nodeId;
  final String specId;
  final ProcessKind kind;

  /// Source and sink nodes stand for the world outside the build, so they are
  /// left out of the power, heat and labour totals — a spare-power outlet is
  /// where surplus *goes*, not something that draws.
  bool get isBoundary =>
      kind == ProcessKind.source || kind == ProcessKind.sink;

  /// Effective running units. Fractional is meaningful: 2.5 Electrolyzers means
  /// three of them, one running half the time.
  final double count;
  final double uptime;

  /// Net watts for this node (negative = it generates).
  final double powerWatts;

  /// Net kDTU/s this node dumps into the base.
  final double heatKdtu;
  final double dupeLabourSecondsPerCycle;

  /// Tiles one of these occupies.
  final int footprintTiles;

  /// The room this node's buildings actually take. Whole buildings, because
  /// half an Electrolyzer takes as much floor as a whole one.
  int get totalFootprintTiles => footprintTiles * wholeCount;

  /// How many you must actually build, accounting for the node's duty cycle.
  double get physicalCount => uptime <= 0 ? count : count / uptime;

  /// How many you must actually build, rounded up to whole buildings.
  int get wholeCount => physicalCount <= 0 ? 0 : physicalCount.ceil();

  /// 1.0 = the whole build is busy; 0.8 = 20 % of the built capacity is idle.
  double get utilisation => wholeCount == 0 ? 0 : physicalCount / wholeCount;
}

/// The supply/demand picture at a single port.
class PortBalance {
  const PortBalance({
    required this.ref,
    required this.itemId,
    required this.direction,
    required this.rate,
    required this.linkedRate,
  });

  final PortRef ref;
  final String itemId;
  final PortDirection direction;

  /// Total the port needs (input) or makes (output), in the item's unit per second.
  final double rate;

  /// The part of [rate] covered by edges.
  final double linkedRate;

  /// Input: what you must supply from outside the pipeline.
  /// Output: what comes out the far end (surplus, vented or stored).
  double get unlinkedRate => rate - linkedRate;

  bool get isExternalInput =>
      direction == PortDirection.input && unlinkedRate > 1e-9;
  bool get isSurplus =>
      direction == PortDirection.output && unlinkedRate > 1e-9;

  /// A fed input port that still does not get enough — should be ~0 after a
  /// successful solve, so a non-zero value is a red flag worth showing.
  double get shortage =>
      direction == PortDirection.input && linkedRate > 0 ? unlinkedRate : 0;
}

/// Per-item totals across the whole pipeline.
class ItemBalance {
  const ItemBalance({
    required this.itemId,
    required this.produced,
    required this.consumed,
    required this.externalInput,
    required this.externalOutput,
  });

  final String itemId;
  final double produced;
  final double consumed;

  /// Must be brought in from outside (geysers, stockpiles, other builds).
  final double externalInput;

  /// Leaves the pipeline (surplus to vent, store or sell).
  final double externalOutput;

  double get net => produced - consumed;
}

/// Everything the engine can tell you about a pipeline at a given scale.
class PipelineSolution {
  const PipelineSolution({
    required this.status,
    required this.issues,
    required this.nodes,
    required this.edgeFlows,
    required this.portBalances,
    required this.itemBalances,
    required this.freeNodeIds,
  });

  factory PipelineSolution.invalid(List<PipelineIssue> issues) =>
      PipelineSolution(
        status: SolveStatus.invalid,
        issues: issues,
        nodes: const {},
        edgeFlows: const {},
        portBalances: const [],
        itemBalances: const {},
        freeNodeIds: const [],
      );

  final SolveStatus status;
  final List<PipelineIssue> issues;

  /// Node id → result.
  final Map<String, NodeResult> nodes;

  /// Edge id → flow in the item's unit per second.
  final Map<String, double> edgeFlows;
  final List<PortBalance> portBalances;

  /// Item id → totals.
  final Map<String, ItemBalance> itemBalances;

  /// Nodes the solver could not pin down; pinning any of them helps.
  final List<String> freeNodeIds;

  bool get isUsable =>
      status == SolveStatus.solved || status == SolveStatus.underdetermined;

  double get powerConsumedWatts => _sumPositive((n) => n.powerWatts);
  double get powerGeneratedWatts => -_sumNegative((n) => n.powerWatts);

  /// Positive = surplus power, negative = you are short.
  double get netPowerWatts => powerGeneratedWatts - powerConsumedWatts;

  double get totalHeatKdtu {
    var total = 0.0;
    for (final n in nodes.values) {
      if (n.isBoundary) continue;
      total += n.heatKdtu * n.count;
    }
    return total;
  }

  /// Floor space the whole build needs, in tiles.
  int get totalFootprintTiles {
    var total = 0;
    for (final n in nodes.values) {
      if (n.isBoundary) continue;
      total += n.totalFootprintTiles;
    }
    return total;
  }

  /// The shopping list: [BuildMaterials] id → kilograms, for the whole build.
  ///
  /// Counted per building actually placed, not per fractional one — half an
  /// Electrolyzer still costs 200 kg of ore — and so it moves in steps as a
  /// build grows, which is the honest shape of the number.
  Map<String, double> constructionMaterials(GameDatabase database) {
    final total = <String, double>{};
    for (final node in nodes.values) {
      if (node.isBoundary) continue;
      final spec = database.process(node.specId);
      if (spec == null) continue;
      for (final entry in spec.buildCost.entries) {
        total[entry.key] =
            (total[entry.key] ?? 0) + entry.value * node.wholeCount;
      }
    }
    return total;
  }

  /// Buildings in this pipeline whose construction cost nobody has checked.
  ///
  /// A shopping list that quietly omits a building is worse than no list, so
  /// this is what lets the total say "and three I could not price".
  Set<String> unpricedBuildings(GameDatabase database) => {
        for (final node in nodes.values)
          if (!node.isBoundary && node.kind == ProcessKind.building)
            if ((database.process(node.specId)?.buildCost ?? const {}).isEmpty)
              node.specId,
      };

  double get dupeLabourSecondsPerCycle {
    var total = 0.0;
    for (final n in nodes.values) {
      if (n.isBoundary) continue;
      total += n.dupeLabourSecondsPerCycle * n.count;
    }
    return total;
  }

  /// Raw resources you must feed in, item id → g/s (or the item's unit).
  Map<String, double> get externalInputs => <String, double>{
        for (final e in itemBalances.entries)
          if (e.value.externalInput > 1e-9) e.key: e.value.externalInput,
      };

  /// What the pipeline gives you back, item id → g/s.
  Map<String, double> get externalOutputs => <String, double>{
        for (final e in itemBalances.entries)
          if (e.value.externalOutput > 1e-9) e.key: e.value.externalOutput,
      };

  List<PortBalance> get shortages =>
      [for (final b in portBalances) if (b.shortage > 1e-6) b];

  double _sumPositive(double Function(NodeResult) f) {
    var total = 0.0;
    for (final n in nodes.values) {
      if (n.isBoundary) continue;
      final v = f(n) * n.count;
      if (v > 0) total += v;
    }
    return total;
  }

  double _sumNegative(double Function(NodeResult) f) {
    var total = 0.0;
    for (final n in nodes.values) {
      if (n.isBoundary) continue;
      final v = f(n) * n.count;
      if (v < 0) total += v;
    }
    return total;
  }
}
