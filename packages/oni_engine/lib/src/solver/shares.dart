import '../graph/pipeline.dart';

/// How much of *something* an edge carries, and which end decided it.
class EdgeFactor {
  const EdgeFactor(this.mode, this.fraction);

  final EdgeMode mode;

  /// [EdgeMode.push]: fraction of the source port's production.
  /// [EdgeMode.pull]: fraction of the target port's demand.
  final double fraction;

  @override
  String toString() => '${mode.name} ${(fraction * 100).toStringAsFixed(0)}%';
}

/// Resolves every edge's fraction.
///
/// Push edges are grouped by their **source** port and share out its production;
/// pull edges are grouped by their **target** port and share out its demand. In
/// both groups an explicit [PipelineEdge.share] is honoured and the unshared
/// edges split what is left equally. Anything still unclaimed is surplus (on an
/// output port) or must come from outside the build (on an input port).
Map<String, EdgeFactor> resolveEdgeFactors(Pipeline pipeline) {
  final pushGroups = <PortRef, List<PipelineEdge>>{};
  final pullGroups = <PortRef, List<PipelineEdge>>{};
  for (final edge in pipeline.edges) {
    if (edge.mode == EdgeMode.push) {
      pushGroups
          .putIfAbsent(PortRef(edge.fromNodeId, edge.fromPortId), () => [])
          .add(edge);
    } else {
      pullGroups
          .putIfAbsent(PortRef(edge.toNodeId, edge.toPortId), () => [])
          .add(edge);
    }
  }

  final factors = <String, EdgeFactor>{};
  void assign(Map<PortRef, List<PipelineEdge>> groups, EdgeMode mode) {
    groups.forEach((_, edges) {
      var explicitTotal = 0.0;
      var unshared = 0;
      for (final edge in edges) {
        if (edge.share != null) {
          explicitTotal += edge.share!;
        } else {
          unshared++;
        }
      }
      final remaining = (1 - explicitTotal).clamp(0.0, 1.0);
      final auto = unshared == 0 ? 0.0 : remaining / unshared;
      for (final edge in edges) {
        factors[edge.id] = EdgeFactor(mode, edge.share ?? auto);
      }
    });
  }

  assign(pushGroups, EdgeMode.push);
  assign(pullGroups, EdgeMode.pull);
  return factors;
}

/// Groups of edges that share a port, used by validation to spot ports that
/// promise more than 100 % of themselves.
Map<PortRef, double> claimedFractions(
  Pipeline pipeline,
  Map<String, EdgeFactor> factors, {
  required EdgeMode mode,
}) {
  final totals = <PortRef, double>{};
  for (final edge in pipeline.edges) {
    if (edge.mode != mode || edge.share == null) continue;
    final ref = mode == EdgeMode.push
        ? PortRef(edge.fromNodeId, edge.fromPortId)
        : PortRef(edge.toNodeId, edge.toPortId);
    totals[ref] = (totals[ref] ?? 0) + edge.share!;
  }
  return totals;
}
