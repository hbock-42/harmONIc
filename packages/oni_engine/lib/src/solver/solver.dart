import '../graph/materials.dart';
import '../graph/pin.dart';
import '../graph/pipeline.dart';
import '../graph/validation.dart';
import '../model/game_database.dart';
import '../model/port.dart';
import '../model/process_spec.dart';
import '../model/units.dart';
import 'linear_algebra.dart';
import 'shares.dart';
import 'solution.dart';

/// Turns a pipeline plus its pins into concrete building counts and flows.
///
/// See `docs/SOLVER.md` for the maths. In short: one variable per node, one
/// balance equation per fed input port, one equation per pin, solved as a
/// single linear system so that recycling loops need no special treatment.
/// Why a row of the linear system exists, so that the answer can say which
/// equation settled a count rather than quoting a row number at somebody.
class _RowReason {
  const _RowReason.balance(this.port) : nodeId = null;
  const _RowReason.pin(String this.nodeId) : port = null;

  /// The port whose balance this row is, where it is one.
  final PortRef? port;

  /// The node whose amount this row is, where it is a pin.
  final String? nodeId;
}

class PipelineSolver {
  const PipelineSolver(this.database);

  final GameDatabase database;

  /// [explain] is how the over-committed-port hint avoids chasing its own
  /// tail: it re-solves the build with one port relaxed, and that inner solve
  /// must not go looking for a culprit of its own.
  PipelineSolution solve(Pipeline pipeline, {bool explain = true}) {
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
    /// The rate a port actually runs at on this node.
    ///
    /// Nothing, if the reader has switched it off — or if it is an output that
    /// only exists because of a port they switched off. Milking is the case
    /// this was written for: stop milking a Glo Squid and the ink stops, and
    /// everything else about the animal carries on.
    ///
    /// One place decides this, so the whole solver honours it: the balance
    /// rows, the flow terms, the pins and the reports all come through here.
    double rateOf(PipelineNode node, Port port) {
      if (node.switchedOff(port.id)) return 0;
      final needs = port.needsPortId;
      if (needs != null && node.switchedOff(needs)) return 0;
      return port.isOutput
          ? port.ratePerSecond * node.outputScale
          : port.ratePerSecond;
    }

    /// The flow along [edge] as a linear term in the node counts, added into
    /// [row]. Which node it lands on is the whole point of the two modes: a
    /// push edge is a fraction of what its source makes, a pull edge is a
    /// fraction of what its target needs.
    void addFlowTerm(List<double> row, PipelineEdge edge, double sign) {
      final factor = factors[edge.id];
      if (factor == null) return;
      switch (factor.mode) {
        case EdgeMode.push:
          final source = pipeline.nodeOrThrow(edge.fromNodeId);
          final port = database
              .processOrThrow(source.specId)
              .portByIdOrThrow(edge.fromPortId);
          row[index[edge.fromNodeId]!] +=
              sign * factor.fraction * rateOf(source, port);
        case EdgeMode.pull:
          final port = database
              .processOrThrow(pipeline.nodeOrThrow(edge.toNodeId).specId)
              .portByIdOrThrow(edge.toPortId);
          row[index[edge.toNodeId]!] +=
              sign * factor.fraction * port.ratePerSecond;
        case EdgeMode.rest:
          // What the port makes, less everything else leaving it. Not a
          // fraction of any one node's count, which is why this is the only
          // mode that has to look at its neighbours: it is an expression, and
          // every term of it is linear, so the solver can carry it.
          final source = pipeline.nodeOrThrow(edge.fromNodeId);
          final ref = PortRef(edge.fromNodeId, edge.fromPortId);
          final port = database
              .processOrThrow(source.specId)
              .portByIdOrThrow(edge.fromPortId);
          final ours = sign * factor.fraction;
          row[index[edge.fromNodeId]!] += ours * rateOf(source, port);
          for (final other in pipeline.edgesOutOf(ref)) {
            if (other.mode == EdgeMode.rest) continue;
            addFlowTerm(row, other, -ours);
          }
      }
    }

    final rows = <List<double>>[];
    final rhs = <double>[];
    // What each row *is*, so that "which equation settled this count" can be
    // said in words rather than as a row number.
    final rowReasons = <_RowReason>[];

    void addRow(void Function(List<double> row) build, double b,
        _RowReason reason) {
      final row = List<double>.filled(nodes.length, 0);
      build(row);
      rows.add(row);
      rhs.add(b);
      rowReasons.add(reason);
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
        // A remainder line is the producer's decision, so a port on the far
        // end of one has to add up to what arrives, exactly as it does for a
        // producer-driven line.
        final drivenFromFarEnd = port.isInput
            ? attached.any((e) => e.mode.isFromSource)
            : attached.any((e) => e.mode == EdgeMode.pull);
        if (!drivenFromFarEnd) continue;
        // A port with a remainder line on it needs no equation: the remainder
        // is *defined* as what makes the sum come out, so the row would be
        // 0 = 0 with extra steps.
        if (port.isOutput && attached.any((e) => e.mode == EdgeMode.rest)) {
          continue;
        }
        // A vented output port makes whatever it makes and the excess goes
        // nowhere in particular, so it constrains nothing.
        if (port.isOutput && node.ventsPort(port.id)) continue;
        addRow((row) {
          for (final edge in attached) {
            addFlowTerm(row, edge, 1);
          }
          row[index[node.id]!] -= rateOf(node, port);
        }, 0, _RowReason.balance(PortRef(node.id, port.id)));
      }
    }

    // Pins.
    for (final pin in pipeline.pins) {
      final column = index[pin.nodeId]!;
      final spec = database.processOrThrow(pipeline.nodeOrThrow(pin.nodeId).specId);
      switch (pin) {
        case BuildingCountPin(:final count):
          addRow((row) => row[column] = 1, count, _RowReason.pin(pin.nodeId));
        case PortRatePin(:final portId, :final ratePerSecond):
          final node = pipeline.nodeOrThrow(pin.nodeId);
          final rate = rateOf(node, spec.portByIdOrThrow(portId));
          addRow((row) => row[column] = rate, ratePerSecond,
              _RowReason.pin(pin.nodeId));
        case StockPin(:final portId):
          final node = pipeline.nodeOrThrow(pin.nodeId);
          final rate = rateOf(node, spec.portByIdOrThrow(portId));
          addRow((row) => row[column] = rate, pin.ratePerSecond,
              _RowReason.pin(pin.nodeId));
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
          // How many amounts it needs, not a menu to choose one from.
          //
          // "Give an amount for one of: Sand output, Water output" was read
          // as an invitation to pick, and giving one left the build exactly
          // as stuck, naming the other. There are as many loose ends as there
          // are amounts to give, and they all have to be given.
          // "Every amount in it could be anything" is true of a build with
          // nothing given anywhere, and false of one that has amounts and has
          // just gained a loose end. Reported on a build that solved until an
          // output node was hung on it: every other figure was still right,
          // and being told the whole thing was unmoored was alarming and
          // untrue.
          switch ((names.length, pipeline.pins.isNotEmpty)) {
            (1, true) => _restRoute(pipeline, freeNodeIds.single) ??
                'Nothing says how big the ${names.single} is yet. '
                    'Give it an amount — the rest of this build is already '
                    'settled by the amounts you have given.',
            (1, false) =>
              'Nothing sets the size of this build yet, so every amount in it '
                  'could be anything. Give an amount for the ${names.single} '
                  'and everything else follows from it.',
            (_, true) => '${names.length} things here have no size yet and '
                'each needs an amount: ${_sentenceList(names)}. Any node on '
                'the same run as one of them will do instead.'
                '${_secondRoute(pipeline, database)}',
            (_, false) =>
              'Nothing sets the size of this build yet, so every amount in '
                  'it could be anything. It has ${names.length} loose ends and '
                  'needs an amount for each: ${_sentenceList(names)}. Any node '
                  'on the same run as one of them will do instead.'
                  '${_secondRoute(pipeline, database)}',
          },
        ));
      case LinearSolveStatus.inconsistent:
        status = SolveStatus.inconsistent;
        resolvedIssues.add(const PipelineIssue(
          IssueSeverity.error,
          'No scale satisfies every constraint at once.',
        ));
        if (explain) {
          resolvedIssues.addAll(_evenlySplitInputHints(pipeline));
          resolvedIssues.addAll(_overCommittedOutputHints(pipeline));
        }
    }

    // Whatever the status: an output node several lines pull into is a mistake
    // in what was drawn, and a build with one can solve perfectly well and
    // still be wrong.
    if (explain) resolvedIssues.addAll(_outputNodeShares(pipeline));

    // Anything that came out negative, said once and blamed on the port that
    // could not supply it.
    //
    // A negative count is never a fact about a base — nothing is built minus
    // five times. It means something is drawn harder than it is made, and it
    // spreads: seven nodes in the build this was reported from, none of them
    // the one at fault, each with its own line saying "check the edge shares".
    // That is true and it is no help at all.
    final negative = <String>[];
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] < -1e-6) {
        negative.add(nodes[i].id);
        status = SolveStatus.inconsistent;
      }
    }
    if (negative.isNotEmpty) {
      // The ports feeding them, which is where the arithmetic ran out.
      // Only ports on nodes that are not themselves below zero. A negative
      // count spreads to everything downstream of it, and those nodes'
      // ports are victims — naming them alongside the cause is how seven
      // messages came to point at six innocent nodes.
      final blame = <PortRef>{};
      for (final id in negative) {
        for (final edge in pipeline.edges) {
          if (edge.toNodeId != id) continue;
          if (negative.contains(edge.fromNodeId)) continue;
          blame.add(PortRef(edge.fromNodeId, edge.fromPortId));
        }
      }
      final names = [
        for (final id in negative)
          database.process(pipeline.nodeOrThrow(id).specId)?.name ?? id,
      ];
      final below = '${_sentenceList(names.toSet().toList())} '
          '${names.length == 1 ? 'came' : 'come'} out below zero, which is not '
          'a thing a base can do.';
      resolvedIssues.add(PipelineIssue(
        IssueSeverity.error,
        // Nobody outside is feeding them, so there is nobody to blame: what
        // they take, they take from each other. A ring that has to start
        // itself, and every time round the shares leave less than went in.
        // Naming a culprit here used to crash -- an empty list of them -- and
        // would have read "more is being drawn from  than they make".
        blame.isEmpty
            ? '$below Everything feeding '
                '${names.length == 1 ? 'it' : 'them'} is one of '
                '${names.length == 1 ? 'it' : 'them'}: a loop with nothing '
                'coming into it from outside, so there is nothing to start it '
                'off. Something in it wants feeding from elsewhere, or an '
                'amount of its own.'
            : '$below More is being drawn from '
                '${_sentenceList([
                    for (final ref in blame)
                      _portDescription(pipeline, ref)
                  ])} '
                'than ${blame.length == 1 ? 'it makes' : 'they make'}: the '
                'shares on the lines off '
                '${blame.length == 1 ? 'it' : 'them'} leave less than what '
                'the rest of the build asks for.',
        nodeId: negative.first,
      ));
    }
    for (var i = 0; i < counts.length; i++) {
      if (counts[i].isNaN || counts[i].isInfinite) {
        counts[i] = 0;
      }
      // Elimination on an over-constrained build lands on -0.0, and every
      // screen that prints a count then says "-0.00 ×" — which reads as a
      // quantity pointing the wrong way rather than as nothing at all.
      counts[i] = _noMinusZero(counts[i]);
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
    //
    // A remainder line has no single driving end -- it is what its port makes
    // less what everything else takes -- so it is worked out the same way the
    // equations were, by adding up its neighbours.
    late final double Function(PipelineEdge) flowOf;
    flowOf = (edge) {
      final factor = factors[edge.id];
      if (factor == null) return 0.0;
      switch (factor.mode) {
        case EdgeMode.push:
        case EdgeMode.pull:
          final driving =
              factor.mode == EdgeMode.push ? edge.fromNodeId : edge.toNodeId;
          final portId =
              factor.mode == EdgeMode.push ? edge.fromPortId : edge.toPortId;
          final drivingNode = pipeline.nodeOrThrow(driving);
          final port = database
              .processOrThrow(drivingNode.specId)
              .portByIdOrThrow(portId);
          return factor.fraction *
              rateOf(drivingNode, port) *
              counts[index[driving]!];
        case EdgeMode.rest:
          final source = pipeline.nodeOrThrow(edge.fromNodeId);
          final port = database
              .processOrThrow(source.specId)
              .portByIdOrThrow(edge.fromPortId);
          var left = rateOf(source, port) * counts[index[source.id]!];
          for (final other
              in pipeline.edgesOutOf(PortRef(edge.fromNodeId, edge.fromPortId))) {
            if (other.mode == EdgeMode.rest) continue;
            left -= flowOf(other);
          }
          return factor.fraction * left;
      }
    };

    final edgeFlows = <String, double>{
      for (final edge in pipeline.edges) edge.id: _noMinusZero(flowOf(edge)),
    };

    // A remainder line that comes out negative.
    //
    // "The rest" is only a sensible thing to say while there is a rest. Where
    // the other lines off a port want more than it makes, the arithmetic
    // answers by running this one backwards, which is a thing no pipe does.
    for (final edge in pipeline.edges) {
      if (edge.mode != EdgeMode.rest) continue;
      final flow = edgeFlows[edge.id] ?? 0;
      if (flow >= -1e-6) continue;
      final ref = PortRef(edge.fromNodeId, edge.fromPortId);
      resolvedIssues.add(PipelineIssue(
        IssueSeverity.error,
        'There is no rest to send: ${_portDescription(pipeline, ref)} is '
        'already spoken for by the other lines off it, and by more than it '
        'makes. This line would have to carry '
        '${(-flow).toStringAsFixed(2)} g/s backwards.',
        nodeId: edge.fromNodeId,
        edgeId: edge.id,
        targets: [
          IssueTarget(_portDescription(pipeline, ref),
              nodeId: edge.fromNodeId, portId: edge.fromPortId),
          IssueTarget('the line carrying the rest', edgeId: edge.id),
        ],
      ));
    }

    // A valve is a cap, and a cap is an inequality this solver cannot hold —
    // so it says when the build breaks one instead of quietly obeying it. The
    // flow above is what the line would *have* to carry; a valve set below
    // that is a valve you will have to open.
    // The same for a ceiling on a supply, which is a valve on the whole of
    // what it gives rather than on one of its lines.
    for (final node in pipeline.nodes) {
      final cap = node.capPerSecond;
      if (cap == null) continue;
      final spec = database.process(node.specId);
      final port = spec?.outputs.firstOrNull;
      final result = nodeResults[node.id];
      if (spec == null || port == null || result == null) continue;
      final gives = port.ratePerSecond * node.outputScale * result.count;
      if (gives <= cap + 1e-6) continue;
      final item = database.item(port.itemId);
      String say(double v) =>
          item?.formatRate(v, RateDisplay.perSecond) ?? v.toStringAsFixed(1);
      resolvedIssues.add(PipelineIssue(
        IssueSeverity.warning,
        'This build needs ${say(gives)} from the '
        '${node.label ?? spec.name}, and you have said you have at most '
        '${say(cap)}. The figures here are what it needs; the ceiling is what '
        'you told it you have.',
        nodeId: node.id,
      ));
    }

    for (final edge in pipeline.edges) {
      final cap = edge.capPerSecond;
      if (cap == null) continue;
      final flow = edgeFlows[edge.id] ?? 0;
      if (flow <= cap + 1e-6) continue;
      final source = pipeline.nodeOrThrow(edge.fromNodeId);
      final sourceSpec = database.processOrThrow(source.specId);
      final item = database.item(itemFlowingIn(database, source, sourceSpec,
          sourceSpec.portByIdOrThrow(edge.fromPortId)));
      resolvedIssues.add(PipelineIssue(
        IssueSeverity.warning,
        'This line has to carry '
        '${item?.formatRate(flow, RateDisplay.perSecond) ?? flow.toStringAsFixed(1)}'
        ', and its valve is set to '
        '${item?.formatRate(cap, RateDisplay.perSecond) ?? cap.toStringAsFixed(1)}'
        '. The figures here are what the build needs; the valve is what you '
        'have allowed it.',
        edgeId: edge.id,
      ));
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
        final made = rateOf(node, port) * count;
        portBalances.add(PortBalance(
          ref: ref,
          itemId: itemFlowingIn(database, node, spec, port),
          direction: port.direction,
          rate: made,
          linkedRate: linked,
        ));

        // Venting an output port drops its balance equation, which is what
        // lets the surplus go. It does not let the *shortfall* be conjured:
        // without this, three wires drawing 4.83 kg/s of sulfur out of a
        // drill making 4.62 solved cleanly, and every count downstream of it
        // was 4.6 % optimistic.
        if (port.isOutput &&
            node.ventsPort(port.id) &&
            linked > made * (1 + 1e-9) + 1e-9) {
          resolvedIssues.add(PipelineIssue(
            IssueSeverity.error,
            'More is being drawn from the ${_portDescription(pipeline, ref)} '
            'than it makes: ${_amount(linked)} against ${_amount(made)}. '
            'Venting lets what is spare go to waste — it cannot make up the '
            'difference.',
            nodeId: node.id,
          ));
          status = SolveStatus.inconsistent;
        }
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
      whyCounts: explain
          ? _whyCounts(pipeline, index, linear, rowReasons, portBalances,
              freeNodeIds)
          : const {},
    );
  }

  /// Input ports fed by more than one wire, where nobody has said how to
  /// divide them.
  ///
  /// Two wires into one input split its demand evenly, because with nothing
  /// else to go on that is the only even-handed guess. It is almost never what
  /// anybody means. Somebody wiring a Petroleum Generator's own polluted water
  /// into an Arbor Tree and adding a supply alongside it means "the generator
  /// gives back what it gives back, and the supply covers the difference" —
  /// and what they get is twice the trees, because the generator's 750 g/s is
  /// read as *half* of what they drink.
  ///
  /// Saying "the producer decides" on both wires expresses it exactly, and
  /// solves: 750 g/s from the generator and 90 topped up. Two people found
  /// this the hard way in one build, so the app says it out loud now.
  /// An output node is a bucket, not a customer.
  ///
  /// It has no size of its own, so "half of what it wants" means "half of
  /// whatever the other line brings" -- which quietly holds every supplier
  /// feeding it to the same amount. Reported as resources going negative for
  /// no visible reason, and the reader was being told to divide something that
  /// has nothing to divide.
  ///
  /// Said whatever the build's status, unlike the hints beside it: this is a
  /// mistake in what was drawn, not an explanation of a failure, and a build
  /// with it can solve perfectly well and be wrong.
  List<PipelineIssue> _outputNodeShares(Pipeline pipeline) {
    final issues = <PipelineIssue>[];
    for (final node in pipeline.nodes) {
      final spec = database.process(node.specId);
      if (spec == null || spec.kind != ProcessKind.sink) continue;
      for (final port in spec.ports) {
        if (!port.isInput) continue;
        final incoming = pipeline.edgesInto(PortRef(node.id, port.id));
        if (incoming.length < 2) continue;
        if (incoming.any((e) => e.mode != EdgeMode.pull || e.share != null)) {
          continue;
        }
        final item =
            database.item(port.itemId)?.name.toLowerCase() ?? port.itemId;
        issues.add(PipelineIssue(
          IssueSeverity.warning,
          '${incoming.length} wires bring $item into this output node, and an '
          'output node has no size of its own — so each of them is reading its '
          'share as a share of whatever the others bring, which holds all '
          '${incoming.length} to the same amount. That is almost never what an '
          'output is for. Set these wires to "the producer" and each will '
          'simply hand over what it makes.',
          nodeId: node.id,
          targets: [
            IssueTarget('the ${spec.name}', nodeId: node.id, portId: port.id),
            for (final edge in incoming)
              IssueTarget(
                  'the line from ${_nodeName(pipeline, edge.fromNodeId)}',
                  edgeId: edge.id),
          ],
          fix: IssueFix(
            incoming.length == 2
                ? 'Set both to the producer'
                : 'Set all ${incoming.length} to the producer',
            producerDrivenEdgeIds: [for (final e in incoming) e.id],
          ),
        ));
      }
    }
    return issues;
  }

  List<PipelineIssue> _evenlySplitInputHints(Pipeline pipeline) {
    final issues = <PipelineIssue>[];
    for (final node in pipeline.nodes) {
      final spec = database.process(node.specId);
      if (spec == null) continue;
      for (final port in spec.ports) {
        if (!port.isInput) continue;
        final incoming = pipeline.edgesInto(PortRef(node.id, port.id));
        if (incoming.length < 2) continue;
        // An explicit share, or a producer-driven wire, means somebody has
        // already said how this port is divided. Only the silent case is a
        // guess worth warning about.
        if (incoming.any((e) => e.mode != EdgeMode.pull || e.share != null)) {
          continue;
        }
        final item =
            database.item(port.itemId)?.name.toLowerCase() ?? port.itemId;
        final targets = [
          IssueTarget('the ${spec.name}', nodeId: node.id, portId: port.id),
          for (final edge in incoming)
            IssueTarget('the line from ${_nodeName(pipeline, edge.fromNodeId)}',
                edgeId: edge.id),
        ];
        if (spec.kind == ProcessKind.sink) continue;
        issues.add(PipelineIssue(
          IssueSeverity.info,
          '${incoming.length} wires bring $item into the ${spec.name}, and '
          'nothing says how to divide it — so each carries an equal share, '
          'which is a guess. If instead each end should hand over what it '
          'makes and one of them take up the slack, set every one of these '
          'wires to "the producer".',
          nodeId: node.id,
          targets: targets,
        ));
      }
    }
    return issues;
  }

  /// An inconsistent system is usually not a contradiction between *pins* — it
  /// is a by-product with nowhere to go. A port drained only by pull edges has
  /// to deliver exactly what it makes, so an Electrolyzer whose hydrogen feeds
  /// a generator that powers it back cannot balance at any size at all: the
  /// generator makes seven times the power the Electrolyzer draws, and both
  /// ports insist on being emptied to the gram.
  ///
  /// Listing every such port was no help. That build has four and three of
  /// them are innocent, so the reader got a wall of identical sentences and no
  /// way to tell which one to act on. Each is tried instead: vent it, solve
  /// again, and if the build comes right then that is the port with the
  /// surplus.
  List<PipelineIssue> _overCommittedOutputHints(Pipeline pipeline) {
    final candidates = <PortRef>[];
    for (final node in pipeline.nodes) {
      final pulled = <String>{};
      for (final edge in pipeline.edges) {
        if (edge.fromNodeId != node.id || edge.mode != EdgeMode.pull) continue;
        pulled.add(edge.fromPortId);
      }
      for (final portId in pulled) {
        if (!node.ventsPort(portId)) candidates.add(PortRef(node.id, portId));
      }
    }
    if (candidates.isEmpty) return const [];

    // Bounded by work rather than by count. A flat ceiling of 24 candidates
    // meant a build with 26 got the wall of names instead of the one port that
    // was over-committed -- and it was over-committed by the node its author
    // had just added, which is the answer they were looking for. A solve costs
    // with the size of the build, so the budget is candidates times nodes.
    final trials = candidates.length * pipeline.nodes.length <= _hintBudget
        ? candidates.length
        : (_hintBudget ~/ pipeline.nodes.length).clamp(1, candidates.length);
    var guilty = <PortRef>[];
    {
      // Venting a port can rescue the arithmetic by collapsing the build
      // instead of fixing it: let the geyser throw its water away and every
      // count sits at zero, which is consistent and useless. So a candidate is
      // judged by what the relaxed build looks like, and the ones that leave
      // nothing running lose to the ones that leave it standing.
      var fewestEmpty = 1 << 30;
      for (final ref in candidates.take(trials)) {
        final relaxed = _solveWithout(pipeline, ref);
        if (relaxed.status == SolveStatus.inconsistent) continue;
        final empty = relaxed.nodes.values.where((n) => n.count.abs() < 1e-9).length;
        if (empty < fewestEmpty) {
          fewestEmpty = empty;
          guilty = [ref];
        } else if (empty == fewestEmpty) {
          guilty.add(ref);
        }
      }
    }

    // Nothing single-handedly explains it. That happens when more than one
    // port is over-committed at once -- reported on a build where venting any
    // one of twenty-six still left it unsolvable, and the reader was handed
    // the whole list and left to guess which mattered.
    //
    // Pairs, where the build is small enough that trying them is not a wait.
    // A solve costs about a millisecond, so C(20,2) is the most that can go
    // between a keystroke and the answer without being felt.
    if (guilty.isEmpty && candidates.length <= _pairCeiling) {
      for (var i = 0; i < candidates.length; i++) {
        for (var j = i + 1; j < candidates.length; j++) {
          final relaxed =
              _solveWithout(pipeline, candidates[i], and: candidates[j]);
          if (relaxed.status == SolveStatus.inconsistent) continue;
          if (relaxed.nodes.values.every((n) => n.count.abs() < 1e-9)) continue;
          return [
            PipelineIssue(
              IssueSeverity.info,
              'No single port explains this one: it takes two. '
              '${_portDescription(pipeline, candidates[i])} and '
              '${_portDescription(pipeline, candidates[j])} both have to hand '
              'over exactly what they make, and between them they cannot. '
              'Give either one somewhere to put its surplus — an output node '
              'or venting — and the rest of the build comes right.',
              nodeId: candidates[i].nodeId,
              targets: [
                for (final ref in [candidates[i], candidates[j]])
                  IssueTarget(_portDescription(pipeline, ref),
                      nodeId: ref.nodeId, portId: ref.portId),
              ],
            ),
          ];
        }
      }
    }

    // Still nothing, and too many candidates to try every pair. Reported with
    // a picture: thirty-one ports named, none of them marked, and the whole
    // list useless. The reader's own way out was the greedy step this refused
    // to take -- give one node somewhere to put its surplus, watch thirty-one
    // become four, repeat.
    //
    // So: vent whichever one leaves the build least broken, hold it vented,
    // and look again. Not exhaustive, and it does not need to be. A set that
    // works is worth far more than the certainty that it is the smallest one,
    // and every port it names is one the reader can act on.
    // Whenever nothing single-handed explains it, and not only when there are
    // too many candidates to pair off exhaustively: a build needing three
    // ports vented defeated the pair search just as thoroughly with five
    // candidates as with thirty-one, and got the same wall of names.
    if (guilty.isEmpty) {
      final set = _smallestSetThatFrees(pipeline, candidates);
      if (set.isNotEmpty) {
        final descriptions = [
          for (final ref in set) _portDescription(pipeline, ref)
        ];
        return [
          PipelineIssue(
            IssueSeverity.info,
            'No one port explains this: it takes ${_inWords(set.length)}. '
            '${_sentenceList(descriptions)} each have to hand over exactly '
            'what they make, and between them they cannot. Give '
            '${set.length == 2 ? 'either' : 'any'} of them somewhere to put '
            'its surplus — an output node, or venting — and the rest of the '
            'build comes right.',
            nodeId: set.first.nodeId,
            targets: [
              for (final ref in set)
                IssueTarget(_portDescription(pipeline, ref),
                    nodeId: ref.nodeId, portId: ref.portId),
            ],
          ),
        ];
      }
    }

    if (guilty.length == 1) {
      final ref = guilty.single;
      return [
        PipelineIssue(
          IssueSeverity.info,
          'Nothing here can take all the ${_portDescription(pipeline, ref)}. '
          'Everything drawing from that port pulls, so it has to hand over '
          'exactly what it makes, and no size of this build makes that add up. '
          '${_supplyAdvice(pipeline, database, ref) ?? 'Send the surplus to an '
              'output node, or mark the port as venting.'}',
          nodeId: ref.nodeId,
          targets: [
            IssueTarget(_portDescription(pipeline, ref),
                nodeId: ref.nodeId, portId: ref.portId),
          ],
        ),
      ];
    }

    // One sentence, however many ports. Saying the same forty words eight
    // times over made the four innocent ports look exactly like the guilty
    // one, which is the complaint that started this.
    final named = guilty.isEmpty ? candidates : guilty;
    // Reported: "sometimes it lists every single node ... it's hard to tell
    // which one is the problem". Past a handful the list has stopped being a
    // shortlist, and a reader is better served by knowing that than by
    // reading thirty names none of which is marked.
    final descriptions = {
      for (final ref in named) _portDescription(pipeline, ref)
    }.toList();
    const shown = 6;
    final tail = descriptions.length > shown
        ? '${_sentenceList(descriptions.take(shown).toList())} '
            'and ${descriptions.length - shown} others'
        : _sentenceList(descriptions);
    // Said out loud when the search came back empty: the reader has been
    // hunting for the one port at fault and there isn't one. Knowing that is
    // worth more than the list, which is why it comes first.
    final noSingleCulprit = guilty.isEmpty
        ? 'No one of these is the problem on its own — venting any single one '
            'still leaves the build unsolvable, so more than one of them is '
            'over-committed. '
        : '';
    return [
      PipelineIssue(
        IssueSeverity.info,
        '$noSingleCulprit'
        'Each of these has to hand over exactly what it makes, because '
        'everything drawing from it pulls: $tail. '
        'Whichever of them has the surplus, either mark that port as venting '
        'or connect an output node to it.',
        nodeId: named.first.nodeId,
        targets: [
          for (final ref in named)
            IssueTarget(_portDescription(pipeline, ref),
                nodeId: ref.nodeId, portId: ref.portId),
        ],
      ),
    ];
  }

  /// The other way out, when there is one worth naming.
  ///
  /// The loose ends this names are wherever the elimination left its free
  /// columns — output nodes, usually, and an amount for one of those is a
  /// thing somebody planning a base does not know yet. What they do know is
  /// what they *have*, and giving every supply an amount is often the whole
  /// answer: it was, in the build this came from.
  ///
  /// Asking an output for as much as possible is the other route, and it only
  /// works once something limits the thing being asked for. Offering it to
  /// somebody whose supplies are all unset sends them to a button that
  /// answers "there is no most", which is what happened.
  static String _secondRoute(Pipeline pipeline, GameDatabase database) {
    final loose = [
      for (final node in pipeline.nodes)
        if (database.process(node.specId)?.kind == ProcessKind.source &&
            !pipeline.pins.any((pin) => pin.nodeId == node.id))
          database.process(node.specId)?.name ?? node.specId,
    ];
    if (loose.isNotEmpty) {
      return ' If you are planning from what you have, give each supply an '
          'amount instead — ${_sentenceList(loose.toSet().toList())} — which '
          'is often the whole answer.';
    }
    return _hasASplit(pipeline)
        ? ' Or ask one of them for as much as possible, and it will choose '
            'the split for you.'
        : '';
  }

  /// Whether anything in the build is divided between several lines.
  ///
  /// Where something is, "how much of it goes where" is a choice rather than
  /// arithmetic, and an amount is not the only way to make it: asking an
  /// output node for as much as possible makes it too. Somebody who has said
  /// what they *have* — 180 g/s of gas, say — has sized the generators and
  /// nothing else, and is owed that second route rather than being told again
  /// to name an amount they do not know yet.
  static bool _hasASplit(Pipeline pipeline) {
    final seen = <PortRef>{};
    for (final edge in pipeline.edges) {
      if (!seen.add(PortRef(edge.fromNodeId, edge.fromPortId))) return true;
    }
    return false;
  }

  /// "a, b and c", so a list of ports reads as a sentence rather than as
  /// output.
  /// How much trial-solving one unsolvable build is worth: candidates times
  /// nodes. Generous, because this runs only when the build is already at a
  /// dead end and a wrong answer here costs somebody an afternoon.
  static const int _hintBudget = 20000;

  /// How many ports it is worth trying in pairs. Every pair is a whole solve,
  /// and this runs between a keystroke and the answer.
  static const int _pairCeiling = 20;


  /// Why each node's amount is the amount it is, in a sentence.
  ///
  /// One equation settles each count, and the elimination knows which. Said
  /// from the answer rather than from the reduced row: the row is a
  /// combination by the time it is used, and what a reader wants is the port
  /// whose arithmetic pinned this down and the two numbers that did it.
  Map<String, String> _whyCounts(
    Pipeline pipeline,
    Map<String, int> index,
    LinearSolution linear,
    List<_RowReason> rowReasons,
    List<PortBalance> portBalances,
    List<String> freeNodeIds,
  ) {
    PortBalance? balanceOf(PortRef ref) {
      for (final b in portBalances) {
        if (b.ref == ref) return b;
      }
      return null;
    }

    final why = <String, String>{};
    for (final node in pipeline.nodes) {
      if (freeNodeIds.contains(node.id)) {
        why[node.id] = 'Nothing settles this yet, so any amount would do. '
            'Give it one, or give one to something on the same run.';
        continue;
      }
      // Its own amount, first and whatever the elimination chose. Several
      // equations can settle one count and the pivot is whichever came to
      // hand; being told a pinned node was settled by its own sulfur, when you
      // typed the number yourself, is true and useless.
      if (pipeline.pins.any((pin) => pin.nodeId == node.id)) {
        why[node.id] = 'You set this one.';
        continue;
      }

      final row = linear.settledBy[index[node.id]!];
      final reason = row == null || row >= rowReasons.length
          ? null
          : rowReasons[row];
      if (reason == null) continue;

      if (reason.nodeId case final String pinned) {
        why[node.id] = pinned == node.id
            ? 'You set this one.'
            : 'It follows from the amount you set on the '
                '${_nodeName(pipeline, pinned)}.';
        continue;
      }

      final ref = reason.port!;
      final balance = balanceOf(ref);
      final spec = database.process(pipeline.node(ref.nodeId)?.specId ?? '');
      final port = spec?.portById(ref.portId);
      final item = port == null ? null : database.item(port.itemId);
      final each = port == null
          ? null
          : item?.formatRate(port.ratePerSecond, RateDisplay.perSecond) ??
              _amount(port.ratePerSecond);
      final linked = balance == null
          ? null
          : item?.formatRate(balance.linkedRate, RateDisplay.perSecond) ??
              _amount(balance.linkedRate);

      final whose = ref.nodeId == node.id
          ? 'its own'
          : '${_nodeName(pipeline, ref.nodeId)}\u2019s';
      final what = item?.name.toLowerCase() ?? ref.portId;
      why[node.id] = linked == null || each == null
          ? 'It is settled by what has to balance at $whose $what.'
          : 'It is settled by $whose $what: $linked ${port!.isInput ? 'arrives' : 'leaves'} '
              'and each one ${port.isInput ? 'takes' : 'makes'} $each.';
    }
    return why;
  }

  /// What to say when the loose end is on the end of a line carrying the rest.
  ///
  /// "The rest" is the one thing that unsizes a producer: a generator was
  /// sized by what drew from it, and once the surplus has somewhere to go it
  /// can be any size at all. Both ends settle the other, and which one somebody
  /// knows depends on what they are planning from — so both are offered.
  String? _restRoute(Pipeline pipeline, String freeNodeId) {
    for (final edge in pipeline.edges) {
      if (edge.mode != EdgeMode.rest || edge.toNodeId != freeNodeId) continue;
      final source = pipeline.node(edge.fromNodeId);
      final maker = source?.label ??
          database.process(source?.specId ?? '')?.name ??
          edge.fromNodeId;
      final taker = pipeline.node(freeNodeId);
      final name = taker?.label ??
          database.process(taker?.specId ?? '')?.name ??
          freeNodeId;
      return 'A line here carries the rest, which means the $maker is no '
          'longer sized by what draws from it — it can be any size, and the '
          'surplus takes up the difference. Give an amount to the $maker, or '
          'to the $name: either settles the other.';
    }
    return null;
  }

  static String _sentenceList(List<String> parts) {
    // Nothing to list. Every caller now checks first and says something else
    // instead, because a sentence with a hole in it is not much better than
    // the crash this used to be -- `take(-1)` on an empty list throws, and a
    // build whose negative nodes were fed only by each other found it.
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.single;
    return '${parts.take(parts.length - 1).join(', ')} and ${parts.last}';
  }

  /// What to do when the port that cannot be emptied belongs to a supply
  /// somebody has given an amount to.
  ///
  /// The field says "I have this much" and the pin means "exactly this much
  /// flows", and those are not the same thing. Somebody planning from what
  /// they have gives every supply its figure — which is the natural reading —
  /// and the one they have plenty of breaks the build, because a supply with
  /// more than the build needs is a contradiction rather than a spare.
  ///
  /// Asked three times how to solve a build from known inputs before this said
  /// anything about it.
  String? _supplyAdvice(
    Pipeline pipeline,
    GameDatabase database,
    PortRef ref,
  ) {
    final node = pipeline.node(ref.nodeId);
    if (node == null) return null;
    if (database.process(node.specId)?.kind != ProcessKind.source) return null;
    if (!pipeline.pins.any((pin) => pin.nodeId == node.id)) return null;
    return 'An amount on a supply means exactly that much flows, not "up to '
        'this much" — so a supply with more than the build needs contradicts '
        'it rather than leaving a spare. Clear the amount and let the build '
        'ask for what it wants, or put the figure on the wire as a valve, '
        'which does mean "at most".';
  }

  /// The build as it would stand if this one port were allowed to overflow.
  /// The fewest ports that, vented together, let the build stand up.
  ///
  /// Greedy: score every candidate by how broken the build still is with it
  /// vented, keep the best, and look again with that one held. Exhaustive
  /// search over pairs is exact and costs C(n,2) solves, which at a
  /// millisecond each is half a second by thirty candidates and worse after;
  /// this costs at most [_mostVents] passes over what is left.
  ///
  /// Empty when it cannot find one, in which case the caller falls back to
  /// naming them all -- which is what used to happen every time.
  List<PortRef> _smallestSetThatFrees(
      Pipeline pipeline, List<PortRef> candidates) {
    final held = <PortRef>[];
    final left = [...candidates];
    var budget = _hintBudget ~/ pipeline.nodes.length;

    for (var pass = 0; pass < _mostVents && left.isNotEmpty; pass++) {
      PortRef? best;
      var bestScore = double.infinity;
      PipelineSolution? bestSolution;
      for (final ref in left) {
        if (budget-- <= 0) return const [];
        final relaxed = _solveWithout(pipeline, ref, alongside: held);
        final score = _howBroken(relaxed);
        if (score < bestScore) {
          bestScore = score;
          best = ref;
          bestSolution = relaxed;
        }
      }
      if (best == null || bestSolution == null) return const [];
      held.add(best);
      left.remove(best);
      // Standing, and standing on something: a build venting its way to all
      // zeroes is consistent and useless, and the single-port pass already
      // turns those down for the same reason.
      if (bestSolution.status != SolveStatus.inconsistent &&
          !bestSolution.nodes.values.every((n) => n.count.abs() < 1e-9)) {
        return held.length > 1 ? held : const [];
      }
    }
    return const [];
  }

  /// How far a relaxed build still is from standing up, smaller being nearer.
  ///
  /// A build that will not balance at any size is further off than one that
  /// balances with something below zero, which is further off than one that
  /// merely leaves a lot of it at nothing.
  static double _howBroken(PipelineSolution solution) {
    final below = solution.nodes.values.where((n) => n.count < -1e-9).length;
    final empty =
        solution.nodes.values.where((n) => n.count.abs() < 1e-9).length;
    final unsolvable =
        solution.status == SolveStatus.inconsistent ? 1000000.0 : 0;
    return unsolvable + below * 1000.0 + empty;
  }

  /// At most this many ports named as over-committed together. Past a few the
  /// answer has stopped being a diagnosis and gone back to being a list.
  static const int _mostVents = 4;

  static String _inWords(int n) => switch (n) {
    2 => 'two',
    3 => 'three',
    4 => 'four',
    _ => '$n',
  };

  PipelineSolution _solveWithout(Pipeline pipeline, PortRef ref,
      {PortRef? and, List<PortRef> alongside = const []}) {
    final relaxing = <String, Set<String>>{};
    for (final each in [ref, if (and != null) and, ...alongside]) {
      relaxing.putIfAbsent(each.nodeId, () => {}).add(each.portId);
    }
    final relaxed = pipeline.copyWith(nodes: [
      for (final node in pipeline.nodes)
        if (relaxing[node.id] case final Set<String> ports)
          node.copyWith(ventedPorts: {...node.ventedPorts, ...ports})
        else
          node,
    ]);
    return solve(relaxed, explain: false);
  }

  /// "Hydrogen Generator's power", for a sentence about a port. A port has no
  /// name of its own — what it carries is the name anybody would use for it.
  /// A flow, in whichever of grams or kilograms a second reads as a number
  /// somebody would say out loud.
  static String _amount(double gramsPerSecond) =>
      gramsPerSecond.abs() >= 1000
          ? '${(gramsPerSecond / 1000).toStringAsFixed(2)} kg/s'
          : '${gramsPerSecond.toStringAsFixed(1)} g/s';

  String _nodeName(Pipeline pipeline, String nodeId) {
    final node = pipeline.node(nodeId);
    return node?.label ?? database.process(node?.specId ?? '')?.name ?? nodeId;
  }

  String _portDescription(Pipeline pipeline, PortRef ref) {
    final node = pipeline.node(ref.nodeId);
    final spec = node == null ? null : database.process(node.specId);
    final port = spec?.portById(ref.portId);
    final item = port == null ? null : database.item(port.itemId);
    final who = node?.label ?? spec?.name ?? ref.nodeId;
    return "$who\u2019s ${item?.name.toLowerCase() ?? ref.portId}";
  }
}


/// Convenience: the app's core gesture — "pin this node to this amount and
/// re-solve everything else".
extension SolvePinned on PipelineSolver {
  PipelineSolution solvePinned(Pipeline pipeline, Pin pin) =>
      solve(pipeline.withOnlyPin(pin));
}

/// Zero with a sign on it is arithmetic showing through, and nothing else.
double _noMinusZero(double value) => value == 0 ? 0 : value;
