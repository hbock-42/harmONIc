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
    final factors = resolveEdgeFactors(pipeline);

    /// A port's rate for a given node. Output ports are scaled by the node's
    /// [PipelineNode.outputScale]; what a node consumes is never scaled.
    double rateOf(PipelineNode node, Port port) =>
        port.isOutput ? port.ratePerSecond * node.outputScale : port.ratePerSecond;

    /// The flow along [edge] as a linear term in the node counts, added into
    /// [row]. Which node it lands on is the whole point of the two modes: a
    /// push edge is a fraction of what its source makes, a pull edge is a
    /// fraction of what its target needs.
    void addFlowTerm(List<double> row, PipelineEdge edge, double sign) {
      final factor = factors[edge.id];
      if (factor == null) return;
      if (factor.mode == EdgeMode.push) {
        final source = pipeline.nodeOrThrow(edge.fromNodeId);
        final port = database
            .processOrThrow(source.specId)
            .portByIdOrThrow(edge.fromPortId);
        row[index[edge.fromNodeId]!] +=
            sign * factor.fraction * rateOf(source, port);
      } else {
        final port = database
            .processOrThrow(pipeline.nodeOrThrow(edge.toNodeId).specId)
            .portByIdOrThrow(edge.toPortId);
        row[index[edge.toNodeId]!] +=
            sign * factor.fraction * port.ratePerSecond;
      }
    }

    final rows = <List<double>>[];
    final rhs = <double>[];

    void addRow(void Function(List<double> row) build, double b) {
      final row = List<double>.filled(nodes.length, 0);
      build(row);
      rows.add(row);
      rhs.add(b);
    }

    // Balance equations. A port only gets one when the edges attached to it are
    // driven from the *other* end:
    //
    //  - an input port fed by a push edge must add up to its demand;
    //  - an output port drained by a pull edge must add up to its production.
    //
    // A port whose edges are all driven from its own side needs no equation:
    // pull edges into an input port already sum to that port's demand by
    // construction, and push edges out of an output port take a fraction of it.
    // Whatever is left over is external supply, or surplus.
    for (final node in nodes) {
      final spec = database.processOrThrow(node.specId);
      for (final port in spec.ports) {
        final ref = PortRef(node.id, port.id);
        final attached =
            port.isInput ? pipeline.edgesInto(ref) : pipeline.edgesOutOf(ref);
        if (attached.isEmpty) continue;
        final drivenFromFarEnd = port.isInput
            ? attached.any((e) => e.mode == EdgeMode.push)
            : attached.any((e) => e.mode == EdgeMode.pull);
        if (!drivenFromFarEnd) continue;
        // A vented output port makes whatever it makes and the excess goes
        // nowhere in particular, so it constrains nothing.
        if (port.isOutput && node.ventsPort(port.id)) continue;
        addRow((row) {
          for (final edge in attached) {
            addFlowTerm(row, edge, 1);
          }
          row[index[node.id]!] -= rateOf(node, port);
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
          final node = pipeline.nodeOrThrow(pin.nodeId);
          final rate = rateOf(node, spec.portByIdOrThrow(portId));
          addRow((row) => row[column] = rate, ratePerSecond);
        case StockPin(:final portId):
          final node = pipeline.nodeOrThrow(pin.nodeId);
          final rate = rateOf(node, spec.portByIdOrThrow(portId));
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
        // Named by what they are, in the words the rest of the app uses. The
        // reader has not met the word "pin" and should not have to.
        final names = [
          for (final id in freeNodeIds)
            database.process(pipeline.nodeOrThrow(id).specId)?.name ?? id,
        ];
        resolvedIssues.add(PipelineIssue(
          IssueSeverity.warning,
          names.length == 1
              ? 'Nothing sets the size of this build yet, so every amount in it '
                  'could be anything. Give an amount for the ${names.single} '
                  'and everything else follows from it.'
              : 'Nothing sets the size of this build yet, so every amount in it '
                  'could be anything. Give an amount for one of: '
                  '${names.join(', ')}.',
        ));
      case LinearSolveStatus.inconsistent:
        status = SolveStatus.inconsistent;
        resolvedIssues.add(const PipelineIssue(
          IssueSeverity.error,
          'No scale satisfies every constraint at once.',
        ));
        resolvedIssues.addAll(_overCommittedOutputHints(pipeline));
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
        kind: spec.kind,
        count: counts[index[node.id]!],
        uptime: node.uptime,
        powerWatts: spec.netPowerWatts,
        heatKdtu: spec.netHeatKdtu,
        dupeLabourSecondsPerCycle: spec.dupeLabourSecondsPerCycle,
        footprintTiles: spec.footprintTiles,
      );
    }

    // Edge flows, read off whichever end drives each edge.
    final edgeFlows = <String, double>{};
    for (final edge in pipeline.edges) {
      final factor = factors[edge.id];
      if (factor == null) {
        edgeFlows[edge.id] = 0;
        continue;
      }
      final driving = factor.mode == EdgeMode.push ? edge.fromNodeId : edge.toNodeId;
      final portId =
          factor.mode == EdgeMode.push ? edge.fromPortId : edge.toPortId;
      final drivingNode = pipeline.nodeOrThrow(driving);
      final port = database
          .processOrThrow(drivingNode.specId)
          .portByIdOrThrow(portId);
      edgeFlows[edge.id] = factor.fraction *
          rateOf(drivingNode, port) *
          counts[index[driving]!];
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
          rate: rateOf(node, port) * count,
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

/// An inconsistent system is usually not a contradiction between *pins* — it is
/// a by-product with nowhere to go. A port drained only by pull edges has to
/// deliver exactly what it makes, so an Electrolyzer whose hydrogen is pulled by
/// a generator cannot also be free to vent the rest. Naming those ports turns a
/// baffling failure into a one-click fix.
List<PipelineIssue> _overCommittedOutputHints(Pipeline pipeline) {
  final hints = <PipelineIssue>[];
  for (final node in pipeline.nodes) {
    final pulled = <String>{};
    for (final edge in pipeline.edges) {
      if (edge.fromNodeId != node.id || edge.mode != EdgeMode.pull) continue;
      pulled.add(edge.fromPortId);
    }
    for (final portId in pulled) {
      if (node.ventsPort(portId)) continue;
      hints.add(PipelineIssue(
        IssueSeverity.info,
        'Port ${node.id}.$portId must deliver exactly what it produces, because '
        'everything drawing from it pulls. If the rest should go to waste, mark '
        'the port as venting; if it should go somewhere, connect an output node.',
        nodeId: node.id,
      ));
    }
  }
  return hints;
}

/// Kept close to the solver so power/heat stay ordinary items everywhere.
const Set<String> nonMassItems = {WellKnownItems.power, WellKnownItems.heat};
