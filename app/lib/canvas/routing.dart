/// Wires that go *round* the cards instead of under them.
///
/// Reported with a picture: an Electrolyzer above a Hydrogen Generator, power
/// going back up and hydrogen coming down, and both wires drawn straight
/// through the middle of both cards. A wire under a card is not merely untidy
/// — it is unreadable, because the eye cannot tell which of the two things it
/// disappeared between it came out of.
///
/// This is the standard two-stage recipe from Dobkin, Gansner, Koutsofios and
/// North, *Implementing a General-Purpose Edge Router* (GD'97): find the
/// shortest path that misses every obstacle, then fit a smooth curve to it.
/// Stage one here is a visibility graph over the corners of the cards, with
/// Dijkstra across it. Stage two rounds the corners off, because the point of
/// the exercise is a wire that reads as a wire.
///
/// The paper's third idea — fitting Béziers into the *corridor* and splitting
/// where they escape it — is not done. Rounding the corners of the polyline is
/// cruder and can bulge a little way into a card on a very tight turn. It is
/// also about thirty lines instead of three hundred, and at the size of build
/// anybody has actually sent in, nobody would be able to point at the
/// difference.
library;

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import 'geometry.dart';


/// How far a wire keeps off a card.
///
/// Wide enough that a wire skimming past does not look like it is touching,
/// narrow enough that two cards a normal gap apart still leave a lane between
/// them rather than forcing the whole detour round the outside.
const double kClearance = 12;

/// How far a wire keeps off a card it is plugged into.
///
/// Less than [kClearance], because a wire has business with its own cards and
/// hugging one reads as "attached" rather than as "in the way". Less than
/// [_stub] too, and that is a constraint rather than a preference: the point a
/// wire starts routing from is [_stub] beyond the port, the port sits
/// [NodeLayout.portInset] inside the card, and if the card's own margin
/// swallowed that point the wire would begin inside an obstacle and no route
/// out of it would exist.
const double kOwnClearance = 6;

/// How far a wire leaves a port before it is allowed to turn.
///
/// Every wire in this app leaves and arrives horizontally, and a routed one
/// has to as well or the two kinds look like two different apps.
const double _stub = 20;

/// How finely a candidate curve is checked against the cards.
const int _samples = 40;

/// Beyond this many cards genuinely blocking one wire, the detour is abandoned
/// and the wire goes back to being a plain curve.
///
/// Genuinely blocking, not merely nearby: this counts the cards found to be in
/// the way, which is a far smaller number than the cards a long wire passes
/// anywhere near. Capping the nearby ones instead is what the first version
/// did, and on a full-screen build every long wire had dozens of cards in its
/// bounding box, gave up, and went back to being drawn through them -- which
/// is exactly the wire you most want routed.
///
/// The visibility graph is quadratic in corners and each of its edges is
/// checked against every card, so the work grows sharply in what is in the
/// way. This is less a tuning knob than a promise that a pathological build
/// cannot lock the editor up: a wire drawn through a card is a blemish, and a
/// frozen canvas is not.
const int _obstacleLimit = 24;

/// How many times to look again after routing round what was known to be in
/// the way.
///
/// Going round one card can put a wire across another that it was nowhere near
/// before, so each pass adds whatever the last route ran into and tries again.
/// It settles in two or three; the limit is only there so it terminates.
const int _rounds = 6;

/// Where every wire goes, worked out once for a given arrangement of cards.
///
/// Held rather than recomputed because three separate things ask — the
/// painter, the click test and the flow label — and all three have to agree,
/// or clicking a wire selects a different one from the one under the cursor.
@immutable
class EdgeRouting {
  const EdgeRouting(this._paths);

  /// No routing at all: every wire is the plain curve it always was.
  ///
  /// Used while a card is being dragged. Routing costs far too much to redo
  /// sixty times a second, and the honest alternative to a stale route — which
  /// would leave wires hanging in space away from the ports they belong to —
  /// is no route.
  static const EdgeRouting none = EdgeRouting(<String, Path>{});

  final Map<String, Path> _paths;

  /// How many wires needed taking round something. Most do not: 11 of 52 on
  /// the largest build anybody has sent in.
  int get routedCount => _paths.length;

  /// Whether this wire is one of them.
  ///
  /// [pathFor] cannot answer that: it builds a fresh plain curve for a wire it
  /// has no route for, so what comes back looks the same either way.
  bool isRouted(String edgeId) => _paths.containsKey(edgeId);

  /// The route itself, or null when there is not one.
  Path? routeFor(String edgeId) => _paths[edgeId];

  /// The same routing, less the wires touching any of [nodeIds].
  ///
  /// For dragging. Throwing away *every* route because one card is moving made
  /// the whole picture flinch: reported as "when moving a node, all links
  /// change position for no reason, then go back". Only the wires attached to
  /// what is moving have to give up their route, and those are the only ones
  /// whose route has stopped being true.
  ///
  /// The rest are a little stale -- a card being dragged past them is an
  /// obstacle that has moved -- and staying put while that happens is much
  /// less distracting than jumping twice.
  EdgeRouting exceptTouching(Set<String> nodeIds, Pipeline pipeline) {
    if (nodeIds.isEmpty || _paths.isEmpty) return this;
    final kept = <String, Path>{};
    for (final edge in pipeline.edges) {
      final path = _paths[edge.id];
      if (path == null) continue;
      if (nodeIds.contains(edge.fromNodeId) ||
          nodeIds.contains(edge.toNodeId)) {
        continue;
      }
      kept[edge.id] = path;
    }
    return EdgeRouting(kept);
  }

  /// The routed path for this wire, or the plain curve when it did not need
  /// routing, was not routed, or could not be.
  Path pathFor(String edgeId, Offset from, Offset to) =>
      _paths[edgeId] ?? edgePath(from, to);

  /// Routes every wire in [pipeline] around the cards, including its own two.
  ///
  /// Its own two matter more than they look. A feedback wire -- a Hydrogen
  /// Generator powering the Electrolyzer it is fed by, a Petroleum Generator
  /// powering the Distiller -- leaves the *right* edge of one card and has to
  /// arrive at the *left* edge of the other, so it travels backwards across
  /// the full width of both. Leaving them out of the obstacles, on the
  /// reasonable-sounding grounds that a wire must be allowed to touch the
  /// cards it is attached to, gave those wires a free pass through exactly the
  /// two cards they most obviously run over.
  ///
  /// Measured on real builds, and on copies of one laid out side by side:
  /// 1.1 ms at 41 nodes, 3.8 ms at 123, 8.8 ms at 246, 15 ms at 369. Once per
  /// edit, which is fine, and nowhere near affordable per frame of a drag --
  /// hence dropping the routes of the card being dragged instead.
  ///
  /// The growth that is left is the pass below that asks which cards are near
  /// a given patch of canvas: every wire against every card, a few times over.
  /// A grid index would make it near-constant, and is the first thing to reach
  /// for if a build ever gets big enough for the pause after an edit to show.
  ///
  /// A wire's own cards are not obstacles to it: it starts and ends on them,
  /// so it necessarily touches them, and treating them as things to avoid
  /// makes every route impossible at once.
  factory EdgeRouting.of(
    Pipeline pipeline,
    ProcessSpec? Function(PipelineNode node) specOf,
  ) {
    final rects = <String, Rect>{};
    for (final node in pipeline.nodes) {
      final spec = specOf(node);
      if (spec != null) rects[node.id] = NodeLayout.worldRect(node, spec);
    }

    final paths = <String, Path>{};
    for (final edge in pipeline.edges) {
      final fromNode = pipeline.node(edge.fromNodeId);
      final toNode = pipeline.node(edge.toNodeId);
      if (fromNode == null || toNode == null) continue;
      final fromSpec = specOf(fromNode);
      final toSpec = specOf(toNode);
      if (fromSpec == null || toSpec == null) continue;
      final from =
          NodeLayout.worldPortOffsetOrNull(fromNode, fromSpec, edge.fromPortId);
      final to =
          NodeLayout.worldPortOffsetOrNull(toNode, toSpec, edge.toPortId);
      if (from == null || to == null) continue;

      // The cards in the way, gathered in one pass. Copying the whole list of
      // rectangles per wire and then filtering it was the single biggest cost
      // here: on a 369-node build that is 173 000 rectangles allocated to
      // route 468 wires, before any routing happens.
      List<Rect> near(Rect bounds) {
        final found = <Rect>[];
        for (final entry in rects.entries) {
          // Its own cards keep a smaller clearance: the wire starts and ends
          // on them, and asking it to stand well off a card it is plugged into
          // would either fail outright or push it off its own port.
          final own =
              entry.key == edge.fromNodeId || entry.key == edge.toNodeId;
          final grown =
              entry.value.inflate(own ? kOwnClearance : kClearance);
          if (grown.overlaps(bounds)) found.add(grown);
        }
        return found;
      }

      final routed = _route(from, to, near);
      if (routed != null) paths[edge.id] = routed;
    }
    return EdgeRouting(paths);
  }
}

/// The path from [from] to [to] that keeps clear of [obstacles], or null when
/// the ordinary curve was already clear and nothing needed doing.
///
/// Null rather than the plain curve so that callers can tell "did not need
/// routing" from "was routed", which is the difference between a wire the
/// painter can draw the cheap way and one it cannot.
/// [own] is the wire's own two cards, which are obstacles as well but keep no
/// clearance: the wire starts and ends on them, and standing off a card it is
/// plugged into would either fail outright or push the wire off its own port.
Path? routedEdgePath(
  Offset from,
  Offset to,
  List<Rect> obstacles, {
  List<Rect> own = const <Rect>[],
}) =>
    _route(from, to, (Rect bounds) {
      final near = <Rect>[];
      for (final rect in obstacles) {
        final grown = rect.inflate(kClearance);
        if (grown.overlaps(bounds)) near.add(grown);
      }
      for (final rect in own) {
        final grown = rect.inflate(kOwnClearance);
        if (grown.overlaps(bounds)) near.add(grown);
      }
      return near;
    });

/// The cards near a given patch of canvas, already grown by their clearance.
///
/// A lookup rather than a list, because which cards matter depends on where
/// the wire has been pushed to. Filtering once against the straight line
/// between the two ports was wrong in a way that took a picture to see: going
/// round the first card lifted a wire clean out of that box, into a second
/// card that had never been a candidate and so could never be found.
typedef _CardsNear = List<Rect> Function(Rect bounds);

/// Cards earn their way into the visibility graph by being shown to block this
/// particular wire. Putting every nearby card in it is both far slower and,
/// past a certain build size, fatal: a wire crossing a full screen has dozens
/// of cards in its bounding box and almost none of them in its way.
Path? _route(Offset from, Offset to, _CardsNear near) {
  // Between the stubs, not the ports, for the test as well as the routing. A
  // port dot is laid out *inside* its card, so a path measured from the dot
  // starts inside an obstacle and every wire in the build would report itself
  // as crossing something.
  final start = from + const Offset(_stub, 0);
  final end = to - const Offset(_stub, 0);
  final direct = edgePath(start, end);
  final candidates = near(direct.getBounds());
  if (candidates.isEmpty) return null;
  if (!_pathEnters(direct, candidates)) return null;

  final blocking = <Rect>[];
  var corners = <Offset>[start, end];
  for (var round = 0; round < _rounds; round++) {
    final found = <Rect>[
      for (final rect in near(_boundsOf(corners)))
        if (!blocking.contains(rect) && _polylineEnters(corners, rect)) rect,
    ];
    if (found.isEmpty) break;
    blocking.addAll(found);
    if (blocking.length > _obstacleLimit) return null;
    final next = _shortestPath(start, end, blocking);
    if (next == null) return null;
    corners = next;
  }

  return _smooth(<Offset>[from, ...corners, to]);
}

Rect _boundsOf(List<Offset> points) {
  var left = points.first.dx;
  var right = left;
  var top = points.first.dy;
  var bottom = top;
  for (final p in points) {
    if (p.dx < left) left = p.dx;
    if (p.dx > right) right = p.dx;
    if (p.dy < top) top = p.dy;
    if (p.dy > bottom) bottom = p.dy;
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

/// True when any leg of the polyline passes through [rect].
bool _polylineEnters(List<Offset> points, Rect rect) {
  final inside = rect.deflate(0.5);
  for (var i = 0; i < points.length - 1; i++) {
    if (_segmentEntersRect(points[i], points[i + 1], inside)) return true;
  }
  return false;
}

/// True when any part of [path] passes inside one of [rects].
///
/// Sampled rather than solved. The alternative is intersecting a cubic with
/// four line segments per card, which is exact, slower, and no more useful:
/// this answers a yes/no question whose "yes" only causes a better path to be
/// looked for.
bool _pathEnters(Path path, List<Rect> rects) {
  final metrics = path.computeMetrics().toList();
  if (metrics.isEmpty) return false;
  final metric = metrics.first;
  for (var i = 0; i <= _samples; i++) {
    final at = metric.getTangentForOffset(metric.length * i / _samples);
    if (at == null) continue;
    for (final rect in rects) {
      if (rect.contains(at.position)) return true;
    }
  }
  return false;
}

/// The shortest corner-to-corner path from [start] to [end] that no card is in
/// the way of, or null when the cards enclose one of the ends completely.
///
/// Dijkstra over the visibility graph: the vertices are the two ends and the
/// four corners of every card in the way, and two vertices are joined when the
/// straight line between them crosses nothing. A\* with a straight-line
/// estimate would visit fewer of them, but the graph is at most a hundred
/// vertices wide and building it already cost more than searching it will.
List<Offset>? _shortestPath(Offset start, Offset end, List<Rect> rects) {
  final points = <Offset>[start, end];
  for (final rect in rects) {
    points
      ..add(rect.topLeft)
      ..add(rect.topRight)
      ..add(rect.bottomLeft)
      ..add(rect.bottomRight);
  }

  // A corner swallowed by another card is not somewhere a wire can go.
  //
  // Deflated, and not by accident: Rect.contains is inclusive on the top and
  // left edges, so every rectangle contains its own top-left corner. Testing
  // as written, each card struck out the one corner of itself a wire most
  // often wants, and a wire that should have hopped over a card went the
  // whole way round the bottom of it instead.
  final usable = <int>[
    for (var i = 0; i < points.length; i++)
      if (i < 2 || !rects.any((r) => r.deflate(0.5).contains(points[i]))) i,
  ];

  final visible = <int, List<int>>{for (final i in usable) i: <int>[]};
  for (var a = 0; a < usable.length; a++) {
    for (var b = a + 1; b < usable.length; b++) {
      final i = usable[a];
      final j = usable[b];
      if (_crosses(points[i], points[j], rects)) continue;
      visible[i]!.add(j);
      visible[j]!.add(i);
    }
  }

  const startIndex = 0;
  const endIndex = 1;
  final best = <int, double>{startIndex: 0};
  final cameFrom = <int, int>{};
  final queue =
      HeapPriorityQueue<(double, int)>((x, y) => x.$1.compareTo(y.$1))
        ..add((0, startIndex));
  final settled = <int>{};

  while (queue.isNotEmpty) {
    final (cost, at) = queue.removeFirst();
    if (!settled.add(at)) continue;
    if (at == endIndex) break;
    for (final next in visible[at] ?? const <int>[]) {
      if (settled.contains(next)) continue;
      final through = cost + (points[next] - points[at]).distance;
      if (through < (best[next] ?? double.infinity)) {
        best[next] = through;
        cameFrom[next] = at;
        queue.add((through, next));
      }
    }
  }

  if (!settled.contains(endIndex)) return null;
  final route = <Offset>[];
  for (int? at = endIndex; at != null; at = cameFrom[at]) {
    route.insert(0, points[at]);
    if (at == startIndex) break;
  }
  return route;
}

/// True when the segment ab passes through the inside of any of [rects].
///
/// The rectangles are shrunk a hair first, so that a segment running exactly
/// along a card's edge — which is the whole point of routing to its corners —
/// counts as clear rather than as a collision with the card it is hugging.
bool _crosses(Offset a, Offset b, List<Rect> rects) {
  for (final rect in rects) {
    if (_segmentEntersRect(a, b, rect.deflate(0.5))) return true;
  }
  return false;
}

/// Liang--Barsky: clip the segment against the four half-planes of the
/// rectangle and see whether anything of it survives.
///
/// Written in the textbook's own terms -- the p and q arrays -- rather than
/// inlined per side. The first attempt inlined it and branched on the sign of
/// the direction where the algorithm branches on the sign of *minus* the
/// direction, so every segment came back clear, every wire was "visible" to
/// every other point, and the router confidently drew straight lines through
/// the cards it was written to avoid.
bool _segmentEntersRect(Offset a, Offset b, Rect rect) {
  if (rect.isEmpty) return false;
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final p = <double>[-dx, dx, -dy, dy];
  final q = <double>[
    a.dx - rect.left,
    rect.right - a.dx,
    a.dy - rect.top,
    rect.bottom - a.dy,
  ];
  var enter = 0.0;
  var leave = 1.0;
  for (var i = 0; i < 4; i++) {
    if (p[i].abs() < 1e-12) {
      // Parallel to this side: either wholly outside it, or it says nothing.
      if (q[i] < 0) return false;
      continue;
    }
    final t = q[i] / p[i];
    if (p[i] < 0) {
      if (t > leave) return false;
      if (t > enter) enter = t;
    } else {
      if (t < enter) return false;
      if (t < leave) leave = t;
    }
  }
  return leave > enter;
}

/// A polyline as a curve: corners rounded, ends flat.
///
/// The rounding is the classic midpoint trick — aim a quadratic at each corner
/// and land on the midpoint of the next leg — so the result is one continuous
/// contour. That matters beyond looks: the arrowhead, the flow label and the
/// click test all walk the path with [Path.computeMetrics] and read the first
/// contour, so a path in pieces would lose three quarters of itself.
Path _smooth(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  if (points.length == 2) {
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }
  for (var i = 1; i < points.length - 1; i++) {
    final corner = points[i];
    final next = points[i + 1];
    final radius = math.min(
      16.0,
      math.min((corner - points[i - 1]).distance,
              (next - corner).distance) /
          2,
    );
    final into = _towards(corner, points[i - 1], radius);
    final away = _towards(corner, next, radius);
    path
      ..lineTo(into.dx, into.dy)
      ..quadraticBezierTo(corner.dx, corner.dy, away.dx, away.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}

Offset _towards(Offset from, Offset to, double distance) {
  final delta = to - from;
  final length = delta.distance;
  if (length < 1e-9) return from;
  return from + delta * (distance / length);
}
