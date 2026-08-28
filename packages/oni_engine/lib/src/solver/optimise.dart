import '../graph/pipeline.dart';
import '../graph/pin.dart';
import '../model/game_database.dart';
import '../model/port.dart';
import '../model/process_spec.dart';
import 'simplex.dart';
import 'solution.dart';
import 'solver.dart';

/// The best a build could do, and what it would be doing to get there.
class BestCase {
  const BestCase({
    required this.status,
    this.ratePerSecond = 0,
    this.nodeCounts = const {},
    this.edgeFlows = const {},
    this.runsNothing = false,
  });

  final LpStatus status;

  /// What the objective came to: g/s of the item asked about.
  final double ratePerSecond;

  /// The build that achieves it, in the same units the ordinary solver uses,
  /// so the two can be compared and so the answer can be shown.
  final Map<String, double> nodeCounts;
  final Map<String, double> edgeFlows;

  /// The minimum was "run nothing", which is a true answer and a useless one.
  ///
  /// Kept apart from [status] because the simplex did its job: the build
  /// really can use no ore at all, by making no metal at all. It is the
  /// question that was wrong, not the arithmetic.
  final bool runsNothing;

  bool get isAnswer => status == LpStatus.optimal && !runsNothing;
}

/// The most of [itemId] this build could put out, and the splits that do it.
///
/// The question the ordinary solver cannot answer, because it needs the flows
/// to be free — see `docs/CHOOSING-SHARES.md`. Where one port feeds two things
/// and nobody has said how it divides, the ordinary solver splits it equally,
/// which is a fair guess and rarely the best one. This works out the division
/// that gets the most out of the build.
///
/// It answers, it does not act: the caller takes the rate and pins it, and the
/// ordinary solver produces the numbers as usual. Two solvers whose answers
/// are both on screen would be worse than one that cannot optimise.
///
/// What it respects:
///
/// - every pin, exactly as the ordinary solver does;
/// - a share somebody set by hand, which is a decision and not a gap;
/// - a valve, which the ordinary solver can only complain about afterwards;
/// - a vented port, which constrains nothing, being spare on purpose.
///
/// What it leaves free is the rest: the shares nobody chose.
BestCase mostOf(Pipeline pipeline, GameDatabase database, String itemId) =>
    _optimise(
      pipeline,
      database,
      boundary: ProcessKind.sink,
      itemId: itemId,
    );

/// A total to make as small as the build allows.
///
/// Unlike an item, these are properties of the whole build rather than of a
/// boundary node, and every one of them is a single number per node: what it
/// draws, what it emits, what it stands on.
enum BuildTotal {
  /// Watts, net: generation counts against consumption, so the answer is the
  /// splits that leave the grid best off.
  power,

  /// kDTU/s, net, in the same sense — a build that deletes heat counts.
  heat,

  /// Tiles, before any rounding up. The app builds whole buildings and this
  /// does not know that, so it is the shape of the answer rather than a
  /// promise about the floor plan.
  floor,
}

/// The splits that make [total] as small as this build can.
BestCase leastTotal(
  Pipeline pipeline,
  GameDatabase database,
  BuildTotal total,
) =>
    _optimise(pipeline, database, boundary: null, buildTotal: total);

/// The least of [itemId] this build could get away with using.
///
/// The mirror of [mostOf], and the question you ask once you know what you
/// want: *"I want two kilograms of oxygen a second — what is the least algae
/// that does it?"*. It only means anything when something in the build says
/// what you want, since the cheapest way to make nothing is to make nothing:
/// with no pin at all the answer is a build of nothing, and that is what it
/// will honestly report.
BestCase leastOf(Pipeline pipeline, GameDatabase database, String itemId) =>
    _optimise(
      pipeline,
      database,
      boundary: ProcessKind.source,
      itemId: itemId,
    );

BestCase _optimise(
  Pipeline pipeline,
  GameDatabase database, {
  required ProcessKind? boundary,
  String? itemId,
  BuildTotal? buildTotal,
}) {
  final nodes = pipeline.nodes;
  if (nodes.isEmpty) return const BestCase(status: LpStatus.infeasible);

  // Columns: one per node, then one per edge.
  final nodeColumn = <String, int>{
    for (var i = 0; i < nodes.length; i++) nodes[i].id: i,
  };
  final edgeColumn = <String, int>{
    for (var i = 0; i < pipeline.edges.length; i++)
      pipeline.edges[i].id: nodes.length + i,
  };
  final columns = nodes.length + pipeline.edges.length;

  List<double> row() => List<double>.filled(columns, 0);
  final constraints = <Constraint>[];

  double rateOf(PipelineNode node, Port port) =>
      port.isOutput ? port.ratePerSecond * node.outputScale : port.ratePerSecond;

  for (final node in nodes) {
    final spec = database.processOrThrow(node.specId);
    for (final port in spec.ports) {
      final ref = PortRef(node.id, port.id);
      final attached =
          port.isInput ? pipeline.edgesInto(ref) : pipeline.edgesOutOf(ref);
      if (attached.isEmpty) continue;

      final coefficients = row();
      for (final edge in attached) {
        coefficients[edgeColumn[edge.id]!] += 1;
      }
      coefficients[nodeColumn[node.id]!] -= rateOf(node, port);

      if (port.isInput) {
        // What arrives is what it eats. A node cannot be fed more than it can
        // take, and one that is fed less is a smaller node, not a hungry one:
        // that is what makes the count a variable rather than a wish.
        constraints.add(Constraint.exactly(coefficients, 0));
      } else if (attached.any((e) => e.mode == EdgeMode.rest)) {
        // A remainder line takes whatever is left, so there is no slack to
        // leave: everything off this port is accounted for by construction,
        // and the optimiser has to answer inside the same rule the solver
        // will apply when it reads the answer back.
        constraints.add(Constraint.exactly(coefficients, 0));
      } else if (!node.ventsPort(port.id)) {
        // What leaves is at most what is made. The slack is the surplus the
        // app already reports — and it is the freedom the whole thing needs.
        constraints.add(Constraint.atMost(coefficients, 0));
      }
    }
  }

  // A valve is the one constraint the ordinary solver cannot hold and this one
  // can. There it is a warning after the fact — the build needs more than you
  // have allowed — and here it is a wall the answer is worked out inside.
  for (final edge in pipeline.edges) {
    final cap = edge.capPerSecond;
    if (cap == null) continue;
    constraints.add(Constraint.atMost(row()..[edgeColumn[edge.id]!] = 1, cap));
  }

  // A ceiling on a node is the same idea one step up: not "this pipe carries
  // at most" but "this supply gives at most", which is what somebody planning
  // from what they have means. It has to be one constraint on the node rather
  // than one on each of its lines, or a supply feeding two things gives twice
  // what was allowed.
  for (final node in pipeline.nodes) {
    final cap = node.capPerSecond;
    if (cap == null) continue;
    final spec = database.processOrThrow(node.specId);
    final port = spec.outputs.firstOrNull;
    if (port == null) continue;
    constraints.add(Constraint.atMost(
      row()..[nodeColumn[node.id]!] = rateOf(node, port),
      cap,
    ));
  }

  // A share somebody set by hand is a decision, so the optimiser works around
  // it rather than over it. Left alone, an unshared edge is free.
  //
  // Which end the share is read against is the whole of what it means, and
  // this read every share against the *producer* — the push meaning — while
  // the ordinary solver reads a pull share against the consumer. So a build
  // whose shares this optimiser had itself just written came back through it
  // meaning something else: a supply line carrying 10.7 % of what the trees
  // drink was read as carrying 10.7 % of what the supply makes, and the
  // supply grew ninefold to deliver the same water. Pressing "use as little
  // as possible" again compounded it — 90 g/s, then 191, then 304 — which is
  // how it was reported.
  for (final edge in pipeline.edges) {
    final share = edge.share;
    if (share == null) continue;
    final coefficients = row()..[edgeColumn[edge.id]!] = 1;
    if (edge.mode == EdgeMode.push) {
      final source = pipeline.nodeOrThrow(edge.fromNodeId);
      final port = database
          .processOrThrow(source.specId)
          .portByIdOrThrow(edge.fromPortId);
      coefficients[nodeColumn[source.id]!] = -share * rateOf(source, port);
    } else {
      final target = pipeline.nodeOrThrow(edge.toNodeId);
      final port = database
          .processOrThrow(target.specId)
          .portByIdOrThrow(edge.toPortId);
      coefficients[nodeColumn[target.id]!] = -share * rateOf(target, port);
    }
    constraints.add(Constraint.exactly(coefficients, 0));
  }

  for (final pin in pipeline.pins) {
    final node = pipeline.nodeOrThrow(pin.nodeId);
    final spec = database.processOrThrow(node.specId);
    final coefficients = row();
    switch (pin) {
      case BuildingCountPin(:final count):
        coefficients[nodeColumn[node.id]!] = 1;
        constraints.add(Constraint.exactly(coefficients, count));
      case PortRatePin(:final portId, :final ratePerSecond):
        coefficients[nodeColumn[node.id]!] =
            rateOf(node, spec.portByIdOrThrow(portId));
        constraints.add(Constraint.exactly(coefficients, ratePerSecond));
      case StockPin(:final portId):
        coefficients[nodeColumn[node.id]!] =
            rateOf(node, spec.portByIdOrThrow(portId));
        constraints.add(Constraint.exactly(coefficients, pin.ratePerSecond));
    }
  }

  // What we are asking about. For an item it is every boundary node that
  // carries it, in or out: a boundary node is defined as one unit per g/s, so
  // its count *is* the rate and the objective is their sum. For a whole-build
  // total it is one coefficient per node — what each one draws, emits or
  // stands on.
  final objective = row();
  var asked = false;
  for (final node in nodes) {
    final spec = database.processOrThrow(node.specId);
    final double coefficient;
    if (buildTotal != null) {
      if (spec.kind.isBoundary) continue;
      coefficient = switch (buildTotal) {
        BuildTotal.power => spec.netPowerWatts,
        BuildTotal.heat => spec.netHeatKdtu,
        BuildTotal.floor => spec.footprintTiles.toDouble(),
      };
      if (coefficient == 0) continue;
    } else {
      if (spec.kind != boundary) continue;
      final ports = boundary == ProcessKind.sink ? spec.inputs : spec.outputs;
      if (!ports.any((p) => p.itemId == itemId)) continue;
      coefficient = 1;
    }
    objective[nodeColumn[node.id]!] = coefficient;
    asked = true;
  }
  if (!asked) return const BestCase(status: LpStatus.infeasible);

  final result = boundary == ProcessKind.sink
      ? solveLp(objective: objective, constraints: constraints)
      : minimiseLp(objective: objective, constraints: constraints);
  if (result.status != LpStatus.optimal) {
    return BestCase(status: result.status);
  }
  // Minimising has a trivial winner whenever nothing says what the build is
  // for: use none, make none. Applying that sets every share to zero and
  // leaves a build that reads as unsized — which is what it did, on a pinned
  // supply, which is the first thing anybody tries.
  final minimising = boundary != ProcessKind.sink;
  final stopped = pipeline.edges.isNotEmpty &&
      pipeline.edges.every(
          (edge) => result.values[edgeColumn[edge.id]!].abs() < 1e-9);

  return BestCase(
    status: result.status,
    runsNothing: minimising && stopped,
    ratePerSecond: result.objective,
    nodeCounts: {
      for (final entry in nodeColumn.entries) entry.key: result.values[entry.value],
    },
    edgeFlows: {
      for (final entry in edgeColumn.entries) entry.key: result.values[entry.value],
    },
  );
}


/// The optimiser's answer, written back as shares the ordinary solver reads.
///
/// This is what keeps there being one solver. The simplex says which way the
/// water should go; that is turned into the same shares somebody could have
/// typed, and every number on screen still comes from the elimination that has
/// always produced them. Nothing here is a second opinion about a build.
///
/// A port with one edge is left exactly as it was: there was nothing to
/// choose, and rewriting it would fill the inspector with shares nobody
/// decided.
/// Nothing down a wire is written as *no decision*, not as a share of zero.
///
/// Zero is not a division, it is a deletion — and the wire it deletes is
/// usually the one somebody added on purpose. A spare-power outlet that the
/// answer happened not to need came back with `share: 0`, which locks it shut:
/// the Hydrogen Generator could then only run as large as the Electrolyzer's
/// own draw, the hydrogen it did not burn had nowhere to go, and a plain SPOM
/// would not balance at any size. Reported as "basic build is now broken", and
/// it was: the app had written it.
///
/// Left unshared, the wire carries what is left over, which is what an outlet
/// is for.
///
/// A fraction, written the way somebody would have written it.
///
/// One flow divided by another is 1.0000000000000009 or -6.2e-16 often enough,
/// and a share outside [0, 1] is not a share. Writing one made the app produce
/// builds it then refused to open.
/// Below this a share is arithmetic noise rather than a decision.
///
/// A simplex answer that means "nothing goes this way" comes back as 6e-15
/// rather than as zero, and written down as a share it says that line carries
/// six femto-per-cent of the output -- which starves whatever is on the end of
/// it while looking, at any precision anybody reads, exactly like nothing.
const double _shareNoise = 1e-9;

/// A fraction of a port's output, as a share fit to write down.
double asShare(double fraction) {
  if (!fraction.isFinite) return 0;
  if (fraction <= _shareNoise) return 0;
  if (fraction >= 1 - _shareNoise) return 1;
  return fraction;
}

Pipeline withShares(Pipeline pipeline, GameDatabase database, BestCase best) {
  if (!best.isAnswer) return pipeline;

  double flowOn(String edgeId) => best.edgeFlows[edgeId] ?? 0;

  // Ports fed by several lines where at least one of those lines is also
  // dividing its own producer between several destinations.
  //
  // Such a port used to get one of each: the divided line written as a
  // fraction of production, its sibling as a fraction of demand. That
  // double-counts, because the demand-driven line claims its fraction of the
  // *whole* demand and the other adds its production on top. The whole group
  // goes to push instead, which is an amount rather than a claim on somebody
  // else's total and so cannot double-count.
  final mustPush = <PortRef>{};
  for (final edge in pipeline.edges) {
    final target = PortRef(edge.toNodeId, edge.toPortId);
    if (pipeline.edgesInto(target).length < 2) continue;
    if (pipeline
            .edgesOutOf(PortRef(edge.fromNodeId, edge.fromPortId))
            .length >
        1) {
      mustPush.add(target);
    }
  }

  final edges = <PipelineEdge>[];
  for (final edge in pipeline.edges) {
    // A line that says "the rest" is already an answer, and one that stays
    // true when anything around it changes. Writing a fraction over it would
    // freeze today's numbers into a share somebody has to maintain by hand,
    // which is the thing it exists to avoid.
    if (edge.mode == EdgeMode.rest) {
      edges.add(edge);
      continue;
    }
    final siblingsOut =
        pipeline.edgesOutOf(PortRef(edge.fromNodeId, edge.fromPortId));
    final siblingsIn =
        pipeline.edgesInto(PortRef(edge.toNodeId, edge.toPortId));

    if (siblingsOut.length > 1 ||
        mustPush.contains(PortRef(edge.toNodeId, edge.toPortId))) {
      // A producer divided between several lines: each takes a fraction of
      // what is *made*, which is push, and the rest of the production is the
      // surplus the port already reports.
      final node = pipeline.nodeOrThrow(edge.fromNodeId);
      final port = database
          .processOrThrow(node.specId)
          .portByIdOrThrow(edge.fromPortId);
      final made = port.ratePerSecond *
          node.outputScale *
          (best.nodeCounts[node.id] ?? 0);
      final fraction = made <= 1e-9 ? 0.0 : asShare(flowOn(edge.id) / made);
      edges.add(fraction <= 0
          ? edge.copyWith(mode: EdgeMode.push, clearShare: true)
          : edge.copyWith(mode: EdgeMode.push, share: fraction));
    } else if (siblingsIn.length > 1) {
      // Several lines feeding one port, none of them divided at its own end:
      // each brings a fraction of what that port *needs*, which is pull, and
      // the fractions add to one.
      final total = siblingsIn.fold<double>(0, (sum, e) => sum + flowOn(e.id));
      final fraction =
          total <= 1e-9 ? 0.0 : asShare(flowOn(edge.id) / total);
      edges.add(fraction <= 0
          ? edge.copyWith(mode: EdgeMode.pull, clearShare: true)
          : edge.copyWith(mode: EdgeMode.pull, share: fraction));
    } else {
      edges.add(edge);
    }
  }
  final written = pipeline.copyWith(edges: edges);

  // Ports the answer leaves with something spare are vented — but only if the
  // build will not solve without it.
  //
  // The optimiser allows an output port to make more than its wires carry —
  // the slack is the surplus, and it is the freedom the whole thing needs. The
  // ordinary solver does not: a port drained only by pull wires has to hand
  // over exactly what it makes. So an answer could be one the app then called
  // impossible, which is how "least heat" on a SPOM produced a build that
  // would not balance at any size.
  //
  // Venting is the existing word for "the rest goes to waste", it is what the
  // answer means, and it shows on the node rather than being assumed.
  //
  // Sparingly, though. Where the surplus could just as well have gone down a
  // wire the build already has, leaving it slack costs the optimiser nothing
  // and it does so arbitrarily — venting on that would turn a coin-flip into
  // a setting somebody has to find and undo. So the shares go on first, and
  // the vents only if what came out cannot balance.
  if (PipelineSolver(database).solve(written, explain: false).status ==
      SolveStatus.solved) {
    return written;
  }

  final vented = <String, Set<String>>{};
  for (final node in pipeline.nodes) {
    final spec = database.process(node.specId);
    if (spec == null) continue;
    final count = best.nodeCounts[node.id] ?? 0;
    for (final port in spec.ports) {
      if (!port.isOutput || node.ventsPort(port.id)) continue;
      final out = pipeline.edgesOutOf(PortRef(node.id, port.id));
      if (out.isEmpty) continue;
      final made = port.ratePerSecond * node.outputScale * count;
      final carried = out.fold<double>(0, (sum, e) => sum + flowOn(e.id));
      if (made - carried > 1e-6 * (made.abs() + 1)) {
        (vented[node.id] ??= {...node.ventedPorts}).add(port.id);
      }
    }
  }

  if (vented.isEmpty) return written;
  return written.copyWith(
    nodes: [
      for (final node in written.nodes)
        if (vented[node.id] case final Set<String> ports)
          node.copyWith(ventedPorts: ports)
        else
          node,
    ],
  );
}
