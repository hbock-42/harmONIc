import '../model/game_database.dart';
import '../model/port.dart';
import 'materials.dart';
import 'pin.dart';
import 'pipeline.dart';

enum IssueSeverity { error, warning, info }

/// Something wrong (or merely suspicious) about a pipeline, addressed to the user.
class PipelineIssue {
  const PipelineIssue(this.severity, this.message, {this.nodeId, this.edgeId});

  final IssueSeverity severity;
  final String message;
  final String? nodeId;
  final String? edgeId;

  bool get isError => severity == IssueSeverity.error;

  @override
  String toString() => '[${severity.name}] $message';
}

/// Structural checks that must pass before the solver will touch a pipeline.
List<PipelineIssue> validatePipeline(Pipeline pipeline, GameDatabase db) {
  final issues = <PipelineIssue>[];
  final nodeIds = <String>{};

  for (final node in pipeline.nodes) {
    if (!nodeIds.add(node.id)) {
      issues.add(PipelineIssue(
          IssueSeverity.error, 'Duplicate node id "${node.id}"',
          nodeId: node.id));
    }
    if (db.process(node.specId) == null) {
      issues.add(PipelineIssue(IssueSeverity.error,
          'Node "${node.id}" uses unknown process "${node.specId}"',
          nodeId: node.id));
    }
    if (node.uptime <= 0 || node.uptime > 1) {
      issues.add(PipelineIssue(IssueSeverity.error,
          'Node "${node.id}" has uptime ${node.uptime}, expected ]0, 1]',
          nodeId: node.id));
    }
  }

  final edgeIds = <String>{};
  for (final edge in pipeline.edges) {
    if (!edgeIds.add(edge.id)) {
      issues.add(PipelineIssue(
          IssueSeverity.error, 'Duplicate edge id "${edge.id}"',
          edgeId: edge.id));
      continue;
    }

    final from = pipeline.node(edge.fromNodeId);
    final to = pipeline.node(edge.toNodeId);
    if (from == null || to == null) {
      issues.add(PipelineIssue(IssueSeverity.error,
          'Edge "${edge.id}" references a missing node',
          edgeId: edge.id));
      continue;
    }

    final fromSpec = db.process(from.specId);
    final toSpec = db.process(to.specId);
    if (fromSpec == null || toSpec == null) continue;

    final fromPort = fromSpec.portById(edge.fromPortId);
    final toPort = toSpec.portById(edge.toPortId);
    if (fromPort == null) {
      issues.add(PipelineIssue(IssueSeverity.error,
          'Edge "${edge.id}": "${fromSpec.id}" has no port "${edge.fromPortId}"',
          edgeId: edge.id));
      continue;
    }
    if (toPort == null) {
      issues.add(PipelineIssue(IssueSeverity.error,
          'Edge "${edge.id}": "${toSpec.id}" has no port "${edge.toPortId}"',
          edgeId: edge.id));
      continue;
    }
    if (fromPort.direction != PortDirection.output) {
      issues.add(PipelineIssue(IssueSeverity.error,
          'Edge "${edge.id}" starts at input port "${fromPort.id}"',
          edgeId: edge.id));
    }
    if (toPort.direction != PortDirection.input) {
      issues.add(PipelineIssue(IssueSeverity.error,
          'Edge "${edge.id}" ends at output port "${toPort.id}"',
          edgeId: edge.id));
    }
    // Against what each end is actually set to, not what the recipe says in
    // general: a refinery set to copper no longer feeds an iron port. And
    // "set to" includes what the wires have already decided — a refinery fed
    // iron ore is refining iron whether or not anybody said so.
    final carried = itemFlowingThrough(db, pipeline, from, fromSpec, fromPort);
    final wanted = itemFlowingThrough(db, pipeline, to, toSpec, toPort);
    if (!portAcceptsThrough(db, pipeline, to, toSpec, toPort, carried) &&
        !portAcceptsThrough(db, pipeline, from, fromSpec, fromPort, wanted)) {
      issues.add(PipelineIssue(
          IssueSeverity.error,
          'Edge "${edge.id}" carries $carried into a '
          '$wanted port',
          edgeId: edge.id));
    }
    // To within a rounding, the same slack the sum of them gets below.
    //
    // A share is usually not typed in: the optimiser writes it, by dividing a
    // flow by a production, and that lands on 1.0000000000000009 or on
    // -6.2e-16 often enough. Rejecting those made the app write builds it then
    // refused to open — every wire to zero, and no way out but to draw it
    // again. Reported by somebody who had to.
    if (edge.share case final double share
        when share < -_shareSlack || share > 1 + _shareSlack) {
      issues.add(PipelineIssue(IssueSeverity.error,
          'Edge "${edge.id}" has share $share, expected [0, 1]',
          edgeId: edge.id));
    }
  }

  // Duplicate links between the same two ports.
  final seenLinks = <String>{};
  for (final edge in pipeline.edges) {
    final key = '${edge.fromNodeId}.${edge.fromPortId}'
        '->${edge.toNodeId}.${edge.toPortId}';
    if (!seenLinks.add(key)) {
      issues.add(PipelineIssue(IssueSeverity.warning,
          'Duplicate link $key — merge these edges',
          edgeId: edge.id));
    }
  }

  for (final pin in pipeline.pins) {
    final node = pipeline.node(pin.nodeId);
    if (node == null) {
      issues.add(PipelineIssue(IssueSeverity.error,
          'Pin references missing node "${pin.nodeId}"',
          nodeId: pin.nodeId));
      continue;
    }
    final spec = db.process(node.specId);
    if (spec == null) continue;
    final portId = switch (pin) {
      PortRatePin(:final portId) => portId,
      StockPin(:final portId) => portId,
      BuildingCountPin() => null,
    };
    if (portId != null && spec.portById(portId) == null) {
      issues.add(PipelineIssue(IssueSeverity.error,
          'Pin on node "${pin.nodeId}" targets unknown port "$portId"',
          nodeId: pin.nodeId));
    }
    if (pin is StockPin && pin.durationSeconds <= 0) {
      issues.add(PipelineIssue(IssueSeverity.error,
          'Stock pin on "${pin.nodeId}" needs a positive duration',
          nodeId: pin.nodeId));
    }
    // An amount below nothing. Left to the solver this came back as two
    // errors about negative node counts, both advising a look at the edge
    // shares — which is sound advice for the *other* way a count goes
    // negative and no help at all here, where somebody typed a minus.
    final amount = switch (pin) {
      BuildingCountPin(:final count) => count,
      PortRatePin(:final ratePerSecond) => ratePerSecond,
      StockPin(:final amount) => amount,
    };
    if (amount < 0) {
      issues.add(PipelineIssue(
        IssueSeverity.error,
        'The amount on this node is below nothing. There is no such build.',
        nodeId: pin.nodeId,
      ));
    }
  }

  if (pipeline.pins.isEmpty && pipeline.nodes.isNotEmpty) {
    issues.add(const PipelineIssue(IssueSeverity.warning,
        'Nothing is pinned — pin a node to give the pipeline a scale'));
  }

  // Ports that promise more than 100 % of themselves. Push edges divide up an
  // output port's production; pull edges divide up an input port's demand.
  final claims = <PortRef, double>{};
  for (final edge in pipeline.edges) {
    if (edge.share == null) continue;
    final ref = edge.mode == EdgeMode.push
        ? PortRef(edge.fromNodeId, edge.fromPortId)
        : PortRef(edge.toNodeId, edge.toPortId);
    claims[ref] = (claims[ref] ?? 0) + edge.share!;
  }
  claims.forEach((ref, total) {
    if (total > 1 + _shareSlack) {
      issues.add(PipelineIssue(
          IssueSeverity.error,
          'Port $ref is divided into ${(total * 100).toStringAsFixed(0)} % '
          '— shares must sum to at most 100 %',
          nodeId: ref.nodeId));
    }
  });

  return issues;
}

/// How far outside [0, 1] a share may land before it is somebody's mistake
/// rather than arithmetic's.
///
/// Wide enough for a double divided by a double, and far narrower than any
/// share anybody would set on purpose.
const double _shareSlack = 1e-7;
