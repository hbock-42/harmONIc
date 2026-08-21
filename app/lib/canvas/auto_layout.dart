import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import 'geometry.dart';

/// Arranges a pipeline left to right, so a build reads the way it flows.
///
/// This is Sugiyama's hierarchical layout, in its usual phases: break the
/// cycles, assign each node to a column, replace every edge that skips a column
/// with a chain of dummy vertices, and then reorder each column by barycentre
/// until the wires stop crossing. Nothing here is invented; the algorithm is
/// forty years old and the version that gets these graphs wrong is always the
/// one missing a phase.
///
/// The last step is ours: coordinates are assigned by simply stacking each
/// column and centring it, rather than by the priority or Brandes–Köpf methods.
/// Wires are drawn as curves between ports, so straightening a long edge into
/// its dummy lane would not change what is on screen.
/// Marks a vertex that stands for a wire passing through a column rather than
/// anything the user placed. The prefix is a character no node id can contain.
const String _dummyPrefix = '\u0000edge:';

bool _isDummy(String id) => id.startsWith(_dummyPrefix);

/// One end of a wire, seen from the vertex being placed: who is at the other
/// end, how far down *that* node the wire attaches, and how far down this one.
class _Link {
  const _Link(this.other, this.otherPort, this.ownPort);

  final String other;
  final double otherPort;
  final double ownPort;
}

class AutoLayout {
  const AutoLayout({
    required this.pipeline,
    required this.database,
    this.only = const {},
    this.columnGap = 112,
    this.rowGap = 36,
    this.buildGap = 160,
  });

  final Pipeline pipeline;
  final GameDatabase database;

  /// When given, only these nodes are arranged, and only wires between them are
  /// followed. Someone who has placed part of a build by hand should be able to
  /// tidy the rest without it being undone.
  final Set<String> only;
  final double columnGap;
  final double rowGap;

  /// The clear air between one build and the next. Wider than [rowGap] on
  /// purpose: the gap is the only thing saying these are two separate things
  /// that happen to share a page.
  final double buildGap;

  /// New positions for the nodes in scope, ready to be applied as one edit.
  ///
  /// Each build is arranged on its own and the builds are then stacked down the
  /// page. Laying them out together would put a node from one build in the same
  /// column as a node from the other, which is how two tidy builds come out
  /// looking like one tangled one.
  Map<String, Offset> positions() {
    if (_nodes.isEmpty) return const {};

    final scope = {for (final node in _nodes) node.id};
    final builds = [
      for (final component in connectedComponents(pipeline))
        if (component.intersection(scope).isNotEmpty)
          component.intersection(scope),
    ];
    if (builds.length <= 1) return _arrange(scope);

    // Keep the builds in the order they already sit in, top to bottom, so
    // tidying rearranges a build without shuffling which is which.
    double topOf(Set<String> build) => build
        .map((id) => pipeline.nodeOrThrow(id).y)
        .reduce(math.min);
    builds.sort((a, b) => topOf(a).compareTo(topOf(b)));

    final positions = <String, Offset>{};
    var top = 0.0;
    for (final build in builds) {
      final laid = _arrange(build);
      if (laid.isEmpty) continue;
      final highest =
          laid.values.map((p) => p.dy).reduce(math.min);
      final lowest = laid.entries
          .map((e) => e.value.dy + _sizeOf(e.key).height)
          .reduce(math.max);
      final shift = NodeLayout.snap(top - highest);
      for (final entry in laid.entries) {
        positions[entry.key] = entry.value.translate(0, shift);
      }
      top = lowest + shift + buildGap;
    }
    return positions;
  }

  /// One build, arranged left to right.
  Map<String, Offset> _arrange(Set<String> build) {
    final layout = only.isEmpty && build.length == pipeline.nodes.length
        ? this
        : AutoLayout(
            pipeline: pipeline,
            database: database,
            only: build,
            columnGap: columnGap,
            rowGap: rowGap,
            buildGap: buildGap,
          );
    final forward = layout._forwardEdges();
    final layers = layout._assignLayers(forward);
    return layout._placeColumns(layout._orderWithinColumns(layers, forward));
  }

  /// Edges that go "forwards", with the ones closing a cycle left out.
  ///
  /// A recycling loop has no left-to-right reading — something has to point
  /// backwards — so the layout ignores the edge that closes it and lets the
  /// wire double back instead of stretching the whole graph to accommodate it.
  /// The nodes being arranged: everything, or just the chosen few.
  List<PipelineNode> get _nodes => only.isEmpty
      ? pipeline.nodes
      : [for (final n in pipeline.nodes) if (only.contains(n.id)) n];

  bool _inScope(PipelineEdge edge) =>
      only.isEmpty ||
      (only.contains(edge.fromNodeId) && only.contains(edge.toNodeId));

  List<PipelineEdge> _forwardEdges() {
    final outgoing = <String, List<PipelineEdge>>{};
    for (final edge in pipeline.edges) {
      if (edge.fromNodeId == edge.toNodeId || !_inScope(edge)) continue;
      outgoing.putIfAbsent(edge.fromNodeId, () => []).add(edge);
    }

    final backEdges = <String>{};
    final visited = <String>{};
    final onStack = <String>{};

    void visit(String nodeId) {
      visited.add(nodeId);
      onStack.add(nodeId);
      for (final edge in outgoing[nodeId] ?? const <PipelineEdge>[]) {
        if (onStack.contains(edge.toNodeId)) {
          backEdges.add(edge.id);
        } else if (!visited.contains(edge.toNodeId)) {
          visit(edge.toNodeId);
        }
      }
      onStack.remove(nodeId);
    }

    for (final node in _nodes) {
      if (!visited.contains(node.id)) visit(node.id);
    }

    return [
      for (final edge in pipeline.edges)
        if (edge.fromNodeId != edge.toNodeId &&
            !backEdges.contains(edge.id) &&
            _inScope(edge))
          edge,
    ];
  }

  /// Longest path from the sources: a node sits one column right of its
  /// furthest-left feeder, so nothing is ever drawn upstream of its own input.
  Map<String, int> _assignLayers(List<PipelineEdge> forward) {
    final layer = {for (final n in _nodes) n.id: 0};
    for (var pass = 0; pass < _nodes.length; pass++) {
      var changed = false;
      for (final edge in forward) {
        final from = layer[edge.fromNodeId];
        final to = layer[edge.toNodeId];
        if (from == null || to == null) continue;
        if (to < from + 1) {
          layer[edge.toNodeId] = from + 1;
          changed = true;
        }
      }
      if (!changed) break;
    }
    return layer;
  }

  /// Crossing reduction, Sugiyama's third and fourth phases.
  ///
  /// An edge that spans more than one column is first broken into a chain of
  /// dummy vertices, one per column it passes through. Without them a long wire
  /// is invisible to the ordering — it connects two columns that never look at
  /// each other — and it crosses whatever it likes on the way. With them the
  /// wire has a place in every column it traverses and gets ordered like
  /// anything else.
  ///
  /// Then barycentre sweeps: put each vertex opposite the average position of
  /// what it connects to, alternating down and up. The barycentre heuristic can
  /// make a pass worse as easily as better, so every pass is scored by counting
  /// the crossings it actually leaves and the best ordering seen is the one
  /// returned.
  List<List<String>> _orderWithinColumns(
    Map<String, int> layer,
    List<PipelineEdge> forward,
  ) {
    final depth = layer.values.fold<int>(0, math.max);
    var columns = <List<String>>[for (var i = 0; i <= depth; i++) []];
    for (final node in _nodes) {
      columns[layer[node.id]!].add(node.id);
    }

    // Phase 3: dummy vertices for every edge that skips a column.
    final incoming = <String, List<_Link>>{};
    final outgoing = <String, List<_Link>>{};
    void link(String from, String to, double fromPort, double toPort) {
      incoming.putIfAbsent(to, () => []).add(_Link(from, fromPort, toPort));
      outgoing.putIfAbsent(from, () => []).add(_Link(to, toPort, fromPort));
    }

    for (final edge in forward) {
      final from = layer[edge.fromNodeId];
      final to = layer[edge.toNodeId];
      if (from == null || to == null) continue;
      final fromPort = _portFraction(edge.fromNodeId, edge.fromPortId);
      final toPort = _portFraction(edge.toNodeId, edge.toPortId);
      if (to - from <= 1) {
        link(edge.fromNodeId, edge.toNodeId, fromPort, toPort);
        continue;
      }
      var previous = edge.fromNodeId;
      var previousPort = fromPort;
      for (var column = from + 1; column < to; column++) {
        final dummy = '$_dummyPrefix${edge.id}:$column';
        columns[column].add(dummy);
        link(previous, dummy, previousPort, 0.5);
        previous = dummy;
        previousPort = 0.5;
      }
      link(previous, edge.toNodeId, previousPort, toPort);
    }

    // Where a vertex wants to sit, in units of "rows of the next column
    // along". A node is not a point: its wires leave and arrive at particular
    // port rows, and two nodes feeding the same neighbour used to score
    // identically and fall back on the order they happened to be created in.
    // Adding the far port's height within its node breaks that tie the way the
    // picture wants, and subtracting our own pulls a node up when the wire
    // leaves from low down on it.
    double? barycentre(String vertex, List<_Link> links, List<String> row) {
      final positions = [
        for (final link in links)
          if (row.contains(link.other))
            row.indexOf(link.other) + link.otherPort - link.ownPort,
      ];
      if (positions.isEmpty) return null;
      return positions.reduce((a, b) => a + b) / positions.length;
    }

    void sortBy(List<String> column, Map<String, double?> keys) {
      final original = [...column];
      column.sort((a, b) {
        final ka = keys[a];
        final kb = keys[b];
        // A vertex with nothing to line up against keeps where it was.
        if (ka == null && kb == null) {
          return original.indexOf(a).compareTo(original.indexOf(b));
        }
        if (ka == null) return 1;
        if (kb == null) return -1;
        return ka.compareTo(kb);
      });
    }

    var best = [for (final column in columns) [...column]];
    var fewest = _crossings(columns, outgoing);

    for (var sweep = 0; sweep < 8; sweep++) {
      final downwards = sweep.isEven;
      if (downwards) {
        for (var i = 1; i < columns.length; i++) {
          sortBy(columns[i], {
            for (final id in columns[i])
              id: barycentre(id, incoming[id] ?? const [], columns[i - 1]),
          });
        }
      } else {
        for (var i = columns.length - 2; i >= 0; i--) {
          sortBy(columns[i], {
            for (final id in columns[i])
              id: barycentre(id, outgoing[id] ?? const [], columns[i + 1]),
          });
        }
      }

      final crossings = _crossings(columns, outgoing);
      // On a tie the later ordering wins: a sweep that does not make things
      // worse has still lined the columns up against their neighbours, which
      // is what stops a tidy graph looking arbitrary.
      if (crossings <= fewest) {
        fewest = crossings;
        best = [for (final column in columns) [...column]];
      }
      if (fewest == 0) break;
    }

    return best;
  }

  /// How many pairs of wires cross, counted over the expanded graph.
  ///
  /// Two edges between the same pair of columns cross when their endpoints are
  /// in the opposite order at each end. That is the whole definition, and
  /// counting it is what makes "did that sweep help?" a question with an answer
  /// rather than a hope.
  int _crossings(List<List<String>> columns, Map<String, List<_Link>> outgoing) {
    var total = 0;
    for (var i = 0; i + 1 < columns.length; i++) {
      final left = columns[i];
      final right = columns[i + 1];
      final pairs = <List<double>>[];
      for (var from = 0; from < left.length; from++) {
        for (final link in outgoing[left[from]] ?? const <_Link>[]) {
          final to = right.indexOf(link.other);
          // Position within the column *plus* where the wire attaches to the
          // node. Without the fraction, two wires into one node scored as
          // landing in the same place and their crossing was invisible — which
          // is the commonest crossing there is.
          if (to >= 0) {
            pairs.add([from + link.ownPort, to + link.otherPort]);
          }
        }
      }
      for (var a = 0; a < pairs.length; a++) {
        for (var b = a + 1; b < pairs.length; b++) {
          final crosses = (pairs[a][0] - pairs[b][0]) * (pairs[a][1] - pairs[b][1]);
          if (crosses < 0) total++;
        }
      }
    }
    return total;
  }

  Map<String, Offset> _placeColumns(List<List<String>> columns) {
    final positions = <String, Offset>{};
    var x = 0.0;

    for (final column in columns) {
      var height = 0.0;
      for (final id in column) {
        height += _sizeOf(id).height + rowGap;
      }
      height -= column.isEmpty ? 0 : rowGap;

      var y = -height / 2;
      var widest = 0.0;
      for (final id in column) {
        final size = _sizeOf(id);
        // Dummies take up their lane and are then forgotten: nothing is placed
        // for them, because there is nothing there but wire.
        if (!_isDummy(id)) {
          positions[id] = Offset(NodeLayout.snap(x), NodeLayout.snap(y));
        }
        y += size.height + rowGap;
        widest = math.max(widest, size.width);
      }
      x += widest + columnGap;
    }
    return _straighten(columns, positions);
  }

  /// Slides nodes up and down so wires run flat.
  ///
  /// Sugiyama's fourth phase, which this had been skipping: the columns were
  /// stacked and centred, so a node never moved to meet the wire coming into
  /// it. A long wire crossing two columns arrived wherever the middle of the
  /// column happened to be, and everything downstream of it sagged.
  ///
  /// The rule is the priority method, in its plainest form. Each node wants to
  /// sit where its wires would be flat — its port level with the port at the
  /// other end. The ones with the most wires get their wish first, and the rest
  /// take what room is left, never passing a neighbour and never closer than
  /// [rowGap].
  Map<String, Offset> _straighten(
    List<List<String>> columns,
    Map<String, Offset> positions,
  ) {
    // Where each wire attaches, as an offset from the top of its node.
    double portY(String nodeId, String portId) {
      if (_isDummy(nodeId)) return _sizeOf(nodeId).height / 2;
      final node = pipeline.node(nodeId);
      final spec = node == null ? null : database.process(node.specId);
      if (spec == null || spec.portById(portId) == null) {
        return _sizeOf(nodeId).height / 2;
      }
      return NodeLayout.portOffset(spec, portId).dy;
    }

    final wires =
        <String, List<({String other, double delta, double weight})>>{};
    for (final edge in pipeline.edges) {
      if (!_inScope(edge) || edge.fromNodeId == edge.toNodeId) continue;
      final from = positions[edge.fromNodeId];
      final to = positions[edge.toNodeId];
      if (from == null || to == null) continue;

      final fromY = portY(edge.fromNodeId, edge.fromPortId);
      final toY = portY(edge.toNodeId, edge.toPortId);
      // A wire crossing three columns pulls three times as hard as one going
      // next door. Its sag is spread over more of the picture and it passes
      // more nodes on the way, so when two wires want a node in different
      // places the long one should win — which is what a person does by hand.
      final weight = math.max(
          1.0, (to.dx - from.dx).abs() / (NodeLayout.width + columnGap));

      wires.putIfAbsent(edge.toNodeId, () => []).add(
          (other: edge.fromNodeId, delta: fromY - toY, weight: weight));
      wires.putIfAbsent(edge.fromNodeId, () => []).add(
          (other: edge.toNodeId, delta: toY - fromY, weight: weight));
    }

    final y = {for (final entry in positions.entries) entry.key: entry.value.dy};

    // Straightening a wire can tangle two others: moving a node to meet one
    // port drags everything attached to it. So each pass is scored the way the
    // ordering phase is, and the best arrangement seen is the one kept —
    // fewest crossings first, and only then the flattest.
    var best = {...y};
    var bestScore = _score(positions, y);

    for (var pass = 0; pass < 4; pass++) {
      for (final column in columns) {
        final real = [for (final id in column) if (!_isDummy(id)) id];
        // Most-connected first: a node with four wires has more say about
        // where it sits than one with a single wire that can bend instead.
        double pull(String id) => (wires[id] ?? const [])
            .fold<double>(0, (sum, link) => sum + link.weight);
        final order = [...real]..sort((a, b) => pull(b).compareTo(pull(a)));

        final settled = <String>{};
        for (final id in order) {
          final links = wires[id];
          if (links == null || links.isEmpty) {
            settled.add(id);
            continue;
          }
          // The heaviest wire decides, rather than every wire getting a vote.
          // Averaging leaves a node between two places and satisfies neither:
          // a Flue Coral pulled by a three-column salt water wire and a
          // one-column lime wire sat 112 pixels off both. Letting the long one
          // win puts it level with the salt water and lets the short wire
          // bend, which is what a person does by hand.
          var heaviest = 0.0;
          for (final link in links) {
            if (y[link.other] == null) continue;
            heaviest = math.max(heaviest, link.weight);
          }
          var wanted = 0.0;
          var counted = 0.0;
          for (final link in links) {
            final otherY = y[link.other];
            if (otherY == null || link.weight < heaviest - 1e-9) continue;
            wanted += otherY + link.delta;
            counted += 1;
          }
          if (counted == 0) {
            settled.add(id);
            continue;
          }
          wanted /= counted;

          // Room between the neighbours that have already had their say.
          final index = real.indexOf(id);
          var top = double.negativeInfinity;
          var bottom = double.infinity;
          for (var i = 0; i < real.length; i++) {
            if (i == index || !settled.contains(real[i])) continue;
            final otherY = y[real[i]]!;
            if (i < index) {
              top = math.max(top, otherY + _sizeOf(real[i]).height + rowGap);
            } else {
              bottom = math.min(bottom, otherY - _sizeOf(id).height - rowGap);
            }
          }
          if (top > bottom) {
            settled.add(id);
            continue;
          }
          y[id] = wanted.clamp(top, bottom);
          settled.add(id);
        }
      }

      final score = _score(positions, y);
      if (score.$1 < bestScore.$1 ||
          (score.$1 == bestScore.$1 && score.$2 < bestScore.$2)) {
        best = {...y};
        bestScore = score;
      }
    }

    return {
      for (final entry in positions.entries)
        entry.key: Offset(entry.value.dx, NodeLayout.snap(best[entry.key]!)),
    };
  }

  /// How tangled and how sagging an arrangement is, in that order of concern.
  ///
  /// A wire that droops is untidy; a wire that crosses another is harder to
  /// follow. So crossings are compared first and the drop only breaks ties.
  (int, double) _score(Map<String, Offset> positions, Map<String, double> y) {
    Offset? endOf(String nodeId, String portId) {
      final node = pipeline.node(nodeId);
      final spec = node == null ? null : database.process(node.specId);
      final at = positions[nodeId];
      final top = y[nodeId];
      if (spec == null || at == null || top == null) return null;
      final offset = NodeLayout.portOffsetOrNull(spec, portId);
      return offset == null ? null : Offset(at.dx, top) + offset;
    }

    final segments = <(Offset, Offset, String, String)>[];
    var sag = 0.0;
    for (final edge in pipeline.edges) {
      if (!_inScope(edge) || edge.fromNodeId == edge.toNodeId) continue;
      final a = endOf(edge.fromNodeId, edge.fromPortId);
      final b = endOf(edge.toNodeId, edge.toPortId);
      if (a == null || b == null) continue;
      sag += (a.dy - b.dy).abs();
      segments.add((
        a,
        b,
        '${edge.fromNodeId}.${edge.fromPortId}',
        '${edge.toNodeId}.${edge.toPortId}',
      ));
    }

    double side(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
    var crossings = 0;
    for (var i = 0; i < segments.length; i++) {
      for (var j = i + 1; j < segments.length; j++) {
        final (p1, p2, fromA, toA) = segments[i];
        final (p3, p4, fromB, toB) = segments[j];
        // Wires sharing a port meet there by definition.
        if (fromA == fromB || fromA == toB || toA == fromB || toA == toB) {
          continue;
        }
        final d1 = side(p2 - p1, p3 - p1);
        final d2 = side(p2 - p1, p4 - p1);
        final d3 = side(p4 - p3, p1 - p3);
        final d4 = side(p4 - p3, p2 - p3);
        if ((d1 > 0) != (d2 > 0) && (d3 > 0) != (d4 > 0)) crossings++;
      }
    }
    return (crossings, sag);
  }

  /// How far down a node its port sits, as a fraction of the node's height.
  ///
  /// 0.5 for a dummy, which stands for a wire passing through and has no ports
  /// of its own.
  double _portFraction(String nodeId, String portId) {
    if (_isDummy(nodeId)) return 0.5;
    final node = pipeline.node(nodeId);
    final spec = node == null ? null : database.process(node.specId);
    if (spec == null || spec.portById(portId) == null) return 0.5;
    final size = NodeLayout.sizeOf(spec);
    if (size.height <= 0) return 0.5;
    return NodeLayout.portOffset(spec, portId).dy / size.height;
  }

  Size _sizeOf(String nodeId) {
    // A dummy is a wire passing through, and it is given a lane of its own so
    // the wire has somewhere to go other than across a node.
    if (_isDummy(nodeId)) return const Size(0, 28);
    final node = pipeline.nodeOrThrow(nodeId);
    final spec = database.process(node.specId);
    // A node naming a recipe that has gone still needs somewhere to sit.
    return spec == null ? const Size(NodeLayout.width, 96) : NodeLayout.sizeOf(spec);
  }
}
