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
          // How many amounts it needs, not a menu to choose one from.
          //
          // "Give an amount for one of: Sand output, Water output" was read
          // as an invitation to pick, and giving one left the build exactly
          // as stuck, naming the other. There are as many loose ends as there
          // are amounts to give, and they all have to be given.
          names.length == 1
              ? 'Nothing sets the size of this build yet, so every amount in it '
                  'could be anything. Give an amount for the ${names.single} '
                  'and everything else follows from it.'
              : 'Nothing sets the size of this build yet, so every amount in '
                  'it could be anything. It has ${names.length} loose ends and '
                  'needs an amount for each: ${_sentenceList(names)}. Any node '
                  'on the same run as one of them will do instead.'
                  '${_secondRoute(pipeline, database)}',
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
      resolvedIssues.add(PipelineIssue(
        IssueSeverity.error,
        '${_sentenceList(names.toSet().toList())} '
        '${names.length == 1 ? 'came' : 'come'} out below zero, which is not '
        'a thing a base can do. More is being drawn from '
        '${_sentenceList([for (final ref in blame) _portDescription(pipeline, ref)])} '
        'than ${blame.length == 1 ? 'it makes' : 'they make'}: the shares on '
        'the lines off '
        '${blame.length == 1 ? 'it' : 'them'} leave less than what the rest '
        'of the build asks for.',
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
      edgeFlows[edge.id] = _noMinusZero(factor.fraction *
          rateOf(drivingNode, port) *
          counts[index[driving]!]);
    }

    // A valve is a cap, and a cap is an inequality this solver cannot hold —
    // so it says when the build breaks one instead of quietly obeying it. The
    // flow above is what the line would *have* to carry; a valve set below
    // that is a valve you will have to open.
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
        issues.add(PipelineIssue(
          IssueSeverity.info,
          '${incoming.length} wires bring $item into the ${spec.name}, and '
          'nothing says how to divide it — so each carries an equal share, '
          'which is a guess. If instead each end should hand over what it '
          'makes and one of them take up the slack, set every one of these '
          'wires to "the producer".',
          nodeId: node.id,
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
    return [
      PipelineIssue(
        IssueSeverity.info,
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

  static String _sentenceList(List<String> parts) {
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
  PipelineSolution _solveWithout(Pipeline pipeline, PortRef ref) {
    final relaxed = pipeline.copyWith(nodes: [
      for (final node in pipeline.nodes)
        if (node.id == ref.nodeId)
          node.copyWith(ventedPorts: {...node.ventedPorts, ref.portId})
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
