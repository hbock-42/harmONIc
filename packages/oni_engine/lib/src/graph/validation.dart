import '../model/game_database.dart';
import '../model/port.dart';
import 'materials.dart';
import 'pin.dart';
import 'pipeline.dart';

enum IssueSeverity { error, warning, info }

/// One of the things a message names, and where it is.
///
/// A message that names six ports is six places to look, and the reader has to
/// find each of them on a canvas bigger than the window. Naming them here as
/// well as in the sentence lets whatever shows the message offer each one as
/// something to click.
class IssueTarget {
  const IssueTarget(this.label, {this.nodeId, this.edgeId, this.portId});

  /// What to call it, in the same words the sentence used.
  final String label;
  final String? nodeId;
  final String? edgeId;

  /// The port on [nodeId] the sentence is about, where it is about one.
  final String? portId;
}

/// A change that would settle a message, for anything able to offer to make it.
///
/// Only ever a change somebody could make by hand in a few clicks; this is a
/// shortcut, not an authority. The reader still sees what it did and can undo
/// it.
class IssueFix {
  const IssueFix(
    this.label, {
    this.producerDrivenEdgeIds = const [],
    this.restEdgeIds = const [],
  });

  /// What the button says, in the imperative: "Set them to the producer".
  final String label;

  /// Wires to make producer-driven.
  final List<String> producerDrivenEdgeIds;

  /// Wires to set to "whatever is left".
  ///
  /// The answer to a port whose producer-driven lines have claimed the whole
  /// of it: one of them stops claiming a fixed amount and takes the remainder
  /// instead, which leaves the consumer-driven lines something to draw. It is
  /// what two people worked out for themselves before the app ever offered it.
  final List<String> restEdgeIds;

  bool get isEmpty => producerDrivenEdgeIds.isEmpty && restEdgeIds.isEmpty;
}

/// Something wrong (or merely suspicious) about a pipeline, addressed to the user.
class PipelineIssue {
  const PipelineIssue(
    this.severity,
    this.message, {
    this.nodeId,
    this.edgeId,
    this.targets = const [],
    this.fix,
  });

  final IssueSeverity severity;
  final String message;
  final String? nodeId;
  final String? edgeId;

  /// The change that would settle it, where there is one worth offering.
  final IssueFix? fix;

  /// The things this message names, for anything that can go and show them.
  ///
  /// Empty for a message about one thing, where [nodeId] and [edgeId] already
  /// say which — [places] is the one to read.
  final List<IssueTarget> targets;

  /// Everywhere this message points, however it was written down.
  List<IssueTarget> get places => targets.isNotEmpty
      ? targets
      : [
          if (edgeId != null) IssueTarget('the wire', edgeId: edgeId),
          if (edgeId == null && nodeId != null)
            IssueTarget('the node', nodeId: nodeId),
        ];

  bool get isError => severity == IssueSeverity.error;

  @override
  String toString() => '[${severity.name}] $message';
}

/// Whether a port's producer-driven lines already divide everything it makes.
///
/// A consumer-driven line added to such a port has nothing to take, and the
/// arithmetic answers that by running it backwards. Both the check that
/// refuses the build and the app that draws the wire ask this, so that
/// dropping an output node on a divided port cannot make a build the app will
/// not then solve.
bool portIsFullyDivided(Pipeline pipeline, PortRef ref) {
  final out = pipeline.edgesOutOf(ref);
  // A line saying "the rest" leaves room for everything else by definition.
  if (out.any((edge) => edge.mode == EdgeMode.rest)) return false;
  final pushing = out.where((edge) => edge.mode == EdgeMode.push);
  if (pushing.isEmpty) return false;
  final named = [
    for (final edge in pushing)
      if (edge.share case final double share) share,
  ];
  // A producer-driven line with no share of its own takes what the named ones
  // leave, so one of those claims whatever is left however little is named.
  if (named.length != pushing.length) return true;
  return named.fold<double>(0, (sum, share) => sum + share) >= 1 - _shareSlack;
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
  // A port whose producer-driven lines already come to all of it, with
  // consumer-driven ones still attached.
  //
  // Six producer-driven wires off one generator's power claiming 100 % between
  // them, and three consumer-driven ones added afterwards: there is nothing
  // left for the three to take, and the only way the sums balance is for them
  // to run backwards. That is what a negative amount is, and it spreads —
  // seven nodes in the build this was reported from, none of which was the
  // one at fault. "Check the edge shares" was all it said.
  //
  // "All of it" is not only shares that add to 100 %. A producer-driven line
  // with no share of its own takes what the named ones leave, so *any* of
  // those makes the group come to all of it however little is named — and one
  // such line, with nothing named at all, quietly takes the lot. That was the
  // shape the first version of this check missed, on the very build written
  // to demonstrate it.
  for (final node in pipeline.nodes) {
    final spec = db.process(node.specId);
    if (spec == null) continue;
    for (final port in spec.ports) {
      if (!port.isOutput) continue;
      final ref = PortRef(node.id, port.id);
      final out = pipeline.edgesOutOf(ref);
      final pushing = out.where((edge) => edge.mode == EdgeMode.push);
      // A remainder line is not a claim on the port, it is whatever is left of
      // it -- so a consumer-driven line beside one is never starved.
      if (out.any((edge) => edge.mode == EdgeMode.rest)) continue;
      if (!portIsFullyDivided(pipeline, ref)) continue;
      // Only the consumer-driven ones are victims. A producer-driven line
      // with no share takes what is left, and where nothing is left it
      // carries nothing — which is what the optimiser writes when its answer
      // does not need a line. A consumer-driven one insists on its target's
      // whole demand, and that is what cannot be met.
      final starved = out.where((edge) => edge.mode == EdgeMode.pull).length;
      if (starved == 0) continue;

      final named = [
        for (final edge in pushing)
          if (edge.share case final double share) share,
      ];
      final unnamed = pushing.length - named.length;
      final claimed = named.fold<double>(0, (sum, share) => sum + share);

      issues.add(PipelineIssue(
        IssueSeverity.error,
        '${_describe(pipeline, db, ref)} is already spoken for: its '
        '${pushing.length == 1 ? 'one producer-driven line takes' : '${pushing.length} producer-driven lines take'} '
        'all of it'
        '${unnamed == 0 && pushing.length > 1 ? ', ${(claimed * 100).toStringAsFixed(0)} % between them' : ''}, '
        'so the '
        '${starved == 1 ? 'other line has' : '$starved other lines have'} '
        'nothing to take. '
        '${unnamed > 0 ? 'Set the producer-driven ${unnamed == 1 ? 'line to carry whatever is left, give it a share' : 'lines to carry whatever is left, give them shares'} that leaves something over, or make ' : 'Lower one of the shares, or make '}'
        '${starved == 1 ? 'that line' : 'those lines'} producer-driven too.',
        nodeId: node.id,
        // Offered as a button where there is one line to do it to. A line
        // carrying the remainder claims nothing, so the lines drawing from
        // the port have something to draw -- and unlike lowering a share it
        // needs no number chosen out of the air.
        fix: switch ([for (final e in pushing) if (e.share == null) e]) {
          [final PipelineEdge only] => IssueFix(
              'Let it carry whatever is left',
              restEdgeIds: [only.id],
            ),
          _ => null,
        },
        targets: [
          IssueTarget(_describe(pipeline, db, ref),
              nodeId: node.id, portId: port.id),
          // The starved lines by name, because the fix is on one of them and
          // a wire is the hardest thing on the canvas to find by eye.
          for (final edge in out)
            if (edge.mode == EdgeMode.pull)
              IssueTarget(
                'the line to ${_nodeName(pipeline, db, edge.toNodeId)}',
                edgeId: edge.id,
              ),
        ],
      ));
    }
  }

  // The same mistake seen from the other end: a consumer-driven line into a
  // port that a producer-driven one also feeds.
  //
  // A consumer-driven line with no share of its own brings the port's *whole*
  // demand, so anything pushed into the same port on top of it has nowhere to
  // go. Reported as "linking Cuddle Pip's dirt back to Arbor Tree zeroes a
  // bunch of stuff": the Compost was already pushing dirt into that port, and
  // the new line said "I will bring all of it".
  for (final node in pipeline.nodes) {
    final spec = db.process(node.specId);
    if (spec == null) continue;
    for (final port in spec.ports) {
      if (!port.isInput) continue;
      final ref = PortRef(node.id, port.id);
      final incoming = pipeline.edgesInto(ref);
      final pushed = incoming.where((e) => e.mode.isFromSource).toList();
      final pulled = incoming.where((e) => e.mode == EdgeMode.pull).toList();
      if (pushed.isEmpty || pulled.isEmpty) continue;

      final named = [
        for (final edge in pulled)
          if (edge.share case final double share) share,
      ];
      final claimed = named.fold<double>(0, (sum, share) => sum + share);
      // Room left over is somebody having said so. Only the silent case
      // promises everything.
      if (named.length == pulled.length && claimed < 1 - _shareSlack) continue;

      issues.add(PipelineIssue(
        IssueSeverity.warning,
        '${_describe(pipeline, db, ref)} is promised twice over: its '
        '${pulled.length == 1 ? 'consumer-driven line brings' : '${pulled.length} consumer-driven lines bring'} '
        'the whole of what this needs, so the '
        '${pushed.length == 1 ? 'line pushing into it has' : '${pushed.length} lines pushing into it have'} '
        'nowhere to go — which is what sends the amounts here to zero. Make '
        '${pulled.length == 1 ? 'that line' : 'those lines'} producer-driven '
        'too, so each simply hands over what it makes, or give '
        '${pulled.length == 1 ? 'it a share' : 'them shares'} that leaves room.',
        nodeId: node.id,
        targets: [
          IssueTarget(_describe(pipeline, db, ref),
              nodeId: node.id, portId: port.id),
          for (final edge in pulled)
            IssueTarget(
              'the line from ${_nodeName(pipeline, db, edge.fromNodeId)}',
              edgeId: edge.id,
            ),
        ],
        fix: IssueFix(
          pulled.length == 1
              ? 'Set it to the producer'
              : 'Set all ${pulled.length} to the producer',
          producerDrivenEdgeIds: [for (final e in pulled) e.id],
        ),
      ));
    }
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

/// "the Natural Gas Generator's power", for a message somebody reads rather
/// than a pair of ids.
String _nodeName(Pipeline pipeline, GameDatabase db, String nodeId) {
  final node = pipeline.node(nodeId);
  final spec = node == null ? null : db.process(node.specId);
  return node?.label ?? spec?.name ?? nodeId;
}

String _describe(Pipeline pipeline, GameDatabase db, PortRef ref) {
  final node = pipeline.node(ref.nodeId);
  final spec = node == null ? null : db.process(node.specId);
  final port = spec?.portById(ref.portId);
  final item = port == null ? null : db.item(port.itemId);
  if (spec == null) return 'Port $ref';
  return 'The ${spec.name}\u2019s ${item?.name.toLowerCase() ?? ref.portId}';
}
