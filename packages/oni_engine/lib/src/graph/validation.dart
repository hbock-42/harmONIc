import '../model/game_database.dart';
import '../model/port.dart';
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
    if (fromPort.itemId != toPort.itemId) {
      issues.add(PipelineIssue(
          IssueSeverity.error,
          'Edge "${edge.id}" carries ${fromPort.itemId} into a '
          '${toPort.itemId} port',
          edgeId: edge.id));
    }
    if (edge.share != null && (edge.share! < 0 || edge.share! > 1)) {
      issues.add(PipelineIssue(IssueSeverity.error,
          'Edge "${edge.id}" has share ${edge.share}, expected [0, 1]',
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
  }

  if (pipeline.pins.isEmpty && pipeline.nodes.isNotEmpty) {
    issues.add(const PipelineIssue(IssueSeverity.warning,
        'Nothing is pinned — pin a node to give the pipeline a scale'));
  }

  // Over-committed output ports.
  final portShareTotals = <PortRef, double>{};
  for (final edge in pipeline.edges) {
    if (edge.share == null) continue;
    final ref = PortRef(edge.fromNodeId, edge.fromPortId);
    portShareTotals[ref] = (portShareTotals[ref] ?? 0) + edge.share!;
  }
  portShareTotals.forEach((ref, total) {
    if (total > 1.0000001) {
      issues.add(PipelineIssue(
          IssueSeverity.error,
          'Port $ref sends ${(total * 100).toStringAsFixed(0)} % of its output '
          '— shares must sum to at most 100 %',
          nodeId: ref.nodeId));
    }
  });

  return issues;
}
