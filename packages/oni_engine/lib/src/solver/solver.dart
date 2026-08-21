import '../graph/pin.dart';
import '../graph/pipeline.dart';
import '../graph/validation.dart';
import '../model/game_database.dart';
import '../model/item.dart';
import '../model/port.dart';
import 'linear_algebra.dart';
import 'shares.dart';
import 'solution.dart';

/// Turns a pipeline plus its pins into concrete building counts and flows.
///
/// See `docs/SOLVER.md` for the maths. In short: one variable per node, one
/// balance equation per fed input port, one equation per pin, solved as a
/// single linear system so that recycling loops need no special treatment.
class PipelineSolver {
  const PipelineSolver(this.database);

  final GameDatabase database;

  PipelineSolution solve(Pipeline pipeline) {
    final issues = validatePipeline(pipeline, database);
    if (issues.any((i) => i.isError)) {
      return PipelineSolution.invalid(issues);
    }
    if (pipeline.nodes.isEmpty) {
      return PipelineSolution(
        status: SolveStatus.solved,
        issues: issues,
        nodes: const {},
        edgeFlows: const {},
        portBalances: const [],
        itemBalances: const {},
        freeNodeIds: const [],
      );
    }

    final nodes = pipeline.nodes;
    final index = <String, int>{
      for (var i = 0; i < nodes.length; i++) nodes[i].id: i,
    };
    final shares = resolveShares(pipeline);

    final rows = <List<double>>[];
    final rhs = <double>[];

    void addRow(void Function(List<double> row) build, double b) {
      final row = List<double>.filled(nodes.length, 0);
      build(row);
      rows.add(row);
      rhs.add(b);
    }

    // Balance: every input port that has at least one incoming edge must be
    // fed exactly. Unfed input ports are external supply, not an equation.
    for (final node in nodes) {
      final spec = database.processOrThrow(node.specId);
      for (final port in spec.inputs) {
        final incoming = pipeline.edgesInto(PortRef(node.id, port.id));
        if (incoming.isEmpty) continue;
        addRow((row) {
          for (final edge in incoming) {
            final sourceSpec =
                database.processOrThrow(pipeline.nodeOrThrow(edge.fromNodeId).specId);
            final sourcePort = sourceSpec.portByIdOrThrow(edge.fromPortId);
            row[index[edge.fromNodeId]!] +=
                (shares[edge.id] ?? 0) * sourcePort.ratePerSecond;
          }
          row[index[node.id]!] -= port.ratePerSecond;
        }, 0);
      }
    }

    // Pins.
    for (final pin in pipeline.pins) {
      final column = index[pin.nodeId]!;
      final spec = database.processOrThrow(pipeline.nodeOrThrow(pin.nodeId).specId);
      switch (pin) {
        case BuildingCountPin(:final count):
          addRow((row) => row[column] = 1, count);
        case PortRatePin(:final portId, :final ratePerSecond):
          final rate = spec.portByIdOrThrow(portId).ratePerSecond;
          addRow((row) => row[column] = rate, ratePerSecond);
        case StockPin(:final portId):
          final rate = spec.portByIdOrThrow(portId).ratePerSecond;
          addRow((row) => row[column] = rate, pin.ratePerSecond);
      }
    }

    final linear = solveLinearSystem(rows, rhs, columns: nodes.length);
    final counts = linear.values;

    final resolvedIssues = [...issues];
    final freeNodeIds = [for (final c in linear.freeColumns) nodes[c].id];

    SolveStatus status;
    switch (linear.status) {
      case LinearSolveStatus.unique:
        status = SolveStatus.solved;
      case LinearSolveStatus.underdetermined:
        status = SolveStatus.underdetermined;
        resolvedIssues.add(PipelineIssue(
          IssueSeverity.warning,
          'Not enough pins: ${freeNodeIds.join(', ')} could be any amount. '
          'Pin one of them.',
        ));
      case LinearSolveStatus.inconsistent:
        status = SolveStatus.inconsistent;
        resolvedIssues.add(const PipelineIssue(
          IssueSeverity.error,
          'The pins contradict each other — no scale satisfies them all.',
        ));
    }

    for (var i = 0; i < counts.length; i++) {
      if (counts[i] < -1e-6) {
        resolvedIssues.add(PipelineIssue(
          IssueSeverity.error,
          'Node "${nodes[i].id}" solved to a negative amount '
          '(${counts[i].toStringAsFixed(3)}) — check the edge shares.',
          nodeId: nodes[i].id,
        ));
        status = SolveStatus.inconsistent;
      }
      if (counts[i].isNaN || counts[i].isInfinite) {
        counts[i] = 0;
      }
    }

    // Node results.
    final nodeResults = <String, NodeResult>{};
    for (final node in nodes) {
      final spec = database.processOrThrow(node.specId);
      nodeResults[node.id] = NodeResult(
        nodeId: node.id,
        specId: spec.id,
        count: counts[index[node.id]!],
        uptime: node.uptime,
        powerWatts: spec.netPowerWatts,
        heatKdtu: spec.netHeatKdtu,
        dupeLabourSecondsPerCycle: spec.dupeLabourSecondsPerCycle,
      );
    }

    // Edge flows.
    final edgeFlows = <String, double>{};
    for (final edge in pipeline.edges) {
      final sourceNode = pipeline.nodeOrThrow(edge.fromNodeId);
      final sourcePort = database
          .processOrThrow(sourceNode.specId)
          .portByIdOrThrow(edge.fromPortId);
      edgeFlows[edge.id] = (shares[edge.id] ?? 0) *
          sourcePort.ratePerSecond *
          counts[index[edge.fromNodeId]!];
    }

    // Port balances.
    final portBalances = <PortBalance>[];
    for (final node in nodes) {
      final spec = database.processOrThrow(node.specId);
      final count = counts[index[node.id]!];
      for (final port in spec.ports) {
        final ref = PortRef(node.id, port.id);
        final linked = port.isInput
            ? pipeline
                .edgesInto(ref)
                .fold<double>(0, (sum, e) => sum + (edgeFlows[e.id] ?? 0))
            : pipeline
                .edgesOutOf(ref)
                .fold<double>(0, (sum, e) => sum + (edgeFlows[e.id] ?? 0));
        portBalances.add(PortBalance(
          ref: ref,
          itemId: port.itemId,
          direction: port.direction,
          rate: port.ratePerSecond * count,
          linkedRate: linked,
        ));
      }
    }

    // Item totals.
    final produced = <String, double>{};
    final consumed = <String, double>{};
    final externalIn = <String, double>{};
    final externalOut = <String, double>{};
    for (final balance in portBalances) {
      final map = balance.direction == PortDirection.output ? produced : consumed;
      map[balance.itemId] = (map[balance.itemId] ?? 0) + balance.rate;
      final leftover = balance.unlinkedRate;
      if (leftover > 1e-9) {
        final target =
            balance.direction == PortDirection.output ? externalOut : externalIn;
        target[balance.itemId] = (target[balance.itemId] ?? 0) + leftover;
      }
    }

    final itemBalances = <String, ItemBalance>{
      for (final itemId in {...produced.keys, ...consumed.keys})
        itemId: ItemBalance(
          itemId: itemId,
          produced: produced[itemId] ?? 0,
          consumed: consumed[itemId] ?? 0,
          externalInput: externalIn[itemId] ?? 0,
          externalOutput: externalOut[itemId] ?? 0,
        ),
    };

    return PipelineSolution(
      status: status,
      issues: resolvedIssues,
      nodes: nodeResults,
      edgeFlows: edgeFlows,
      portBalances: portBalances,
      itemBalances: itemBalances,
      freeNodeIds: freeNodeIds,
    );
  }
}

/// Convenience: the app's core gesture — "pin this node to this amount and
/// re-solve everything else".
extension SolvePinned on PipelineSolver {
  PipelineSolution solvePinned(Pipeline pipeline, Pin pin) =>
      solve(pipeline.withOnlyPin(pin));
}

/// Kept close to the solver so power/heat stay ordinary items everywhere.
const Set<String> nonMassItems = {WellKnownItems.power, WellKnownItems.heat};
