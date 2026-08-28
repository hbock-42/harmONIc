import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import 'geometry.dart';
import 'routing.dart';

/// Where each wire's flow figure sits, and what it says.
///
/// Wires are painted *under* the cards — that is what lets a wire pass behind
/// one without cutting a hole in it — so a figure that lands on a card is not
/// merely hard to read. It is not drawn at all. Measured on builds people
/// sent in: eight of forty-nine figures missing on one, five of fifty-two on
/// another, and nothing anywhere to say a figure had gone.
///
/// So each label is slid along its own wire until it is in clear air. Along
/// the wire rather than beside it, because a number floating off a line
/// belongs to no line in particular, and the whole point of the thing is to
/// say how much is going through *this* one.
@immutable
class EdgeLabels {
  const EdgeLabels(this._at, this._text);

  /// Nothing worked out: every label in the middle of its wire, as it was.
  static const EdgeLabels none = EdgeLabels(<String, double>{}, <String, String>{});

  final Map<String, double> _at;
  final Map<String, String> _text;

  /// How far along its wire this label sits.
  double fractionFor(String edgeId) => _at[edgeId] ?? kLabelPosition;

  /// What it says, or null when this wire has no figure worth printing.
  String? textFor(String edgeId) => _text[edgeId];

  /// Works out where every label can go without landing on a card, or on
  /// another label.
  ///
  /// Wires are taken in a fixed order so the answer is the same every time.
  /// Which label gets the good spot when two want it is arbitrary either way;
  /// what matters is that it does not change between frames.
  factory EdgeLabels.place({
    required Pipeline pipeline,
    required GameDatabase database,
    required PipelineSolution solution,
    required EdgeRouting routing,
    required RateDisplay rateDisplay,
    required ProcessSpec? Function(PipelineNode node) specOf,
  }) {
    final cards = <Rect>[
      for (final node in pipeline.nodes)
        if (specOf(node) case final ProcessSpec spec)
          NodeLayout.worldRect(node, spec),
    ];

    final spread = labelFractions(pipeline);
    final at = <String, double>{};
    final texts = <String, String>{};
    final taken = <Rect>[];

    final edges = [...pipeline.edges]..sort((a, b) => a.id.compareTo(b.id));
    for (final edge in edges) {
      final from = pipeline.node(edge.fromNodeId);
      final to = pipeline.node(edge.toNodeId);
      if (from == null || to == null) continue;
      final fromSpec = specOf(from);
      final toSpec = specOf(to);
      if (fromSpec == null || toSpec == null) continue;
      final a =
          NodeLayout.worldPortOffsetOrNull(from, fromSpec, edge.fromPortId);
      final b = NodeLayout.worldPortOffsetOrNull(to, toSpec, edge.toPortId);
      if (a == null || b == null) continue;

      final port = fromSpec.portById(edge.fromPortId);
      final item = port == null ? null : database.item(port.itemId);
      final text = flowLabelText(
          solution.edgeFlows[edge.id] ?? 0, item, rateDisplay);
      texts[edge.id] = text;

      final metrics =
          routing.pathFor(edge.id, a, b).computeMetrics().toList();
      if (metrics.isEmpty) continue;
      final metric = metrics.first;
      final size = labelSize(text);
      final base = spread[edge.id] ?? kLabelPosition;

      Rect? boxAt(double along) {
        final tangent = metric.getTangentForOffset(metric.length * along);
        return tangent == null
            ? null
            : Rect.fromCenter(
                center: tangent.position,
                width: size.width,
                height: size.height,
              );
      }

      // Two things to get out of the way of, and they are not equally bad.
      // Under a card the figure is not drawn at all; over another figure it is
      // merely crowded. So a spot clear of the cards is kept as a fallback and
      // taken if no spot is clear of everything.
      double? clearOfAll;
      Rect? clearOfAllBox;
      double? clearOfCards;
      Rect? clearOfCardsBox;
      for (final along in _tries(base)) {
        final box = boxAt(along);
        if (box == null) continue;
        if (cards.any(box.overlaps)) continue;
        clearOfCards ??= along;
        clearOfCardsBox ??= box;
        if (taken.any(box.overlaps)) continue;
        clearOfAll = along;
        clearOfAllBox = box;
        break;
      }

      // Nowhere on the whole wire is clear of even the cards: leave it where
      // it wanted to be. A figure lost under one card is no better for being
      // lost under a different one, and moving it would only make the wire it
      // belongs to harder to guess.
      at[edge.id] = clearOfAll ?? clearOfCards ?? base;
      final placed = clearOfAllBox ?? clearOfCardsBox;
      if (placed != null) taken.add(placed);
    }
    return EdgeLabels(at, texts);
  }

  /// Where to look, in order: where it wanted to be, then further and further
  /// either side of it, and never so near an end that the figure reads as
  /// belonging to the port rather than to the wire.
  static Iterable<double> _tries(double base) sync* {
    yield base;
    for (var step = 1; step <= 24; step++) {
      final away = step * 0.03;
      final earlier = base - away;
      final later = base + away;
      if (later <= _latest) yield later;
      if (earlier >= _earliest) yield earlier;
    }
  }

  static const double _earliest = 0.14;
  static const double _latest = 0.86;
}

/// How far along a wire its flow label sits, before anything is in the way.
///
/// The middle, because that is where the eye looks for a wire's own label —
/// anywhere else and it reads as belonging to whichever end it sits nearer.
const double kLabelPosition = 0.5;

/// How far apart the labels of wires joining the same two nodes are pushed.
const double _labelSpread = 0.36;

/// Where every wire's label would sit if nothing were in the way.
///
/// The middle, unless several wires join the same pair of nodes: an
/// Electrolyzer feeding a Hydrogen Generator that powers it back has two, and
/// one number printed over another is worse than either being off centre.
/// Those share out a corridor measured from whichever end sorts first, so that
/// a wire running the other way — which walks its own path backwards — lands
/// somewhere else rather than on the same spot.
Map<String, double> labelFractions(Pipeline pipeline) {
  final byPair = <String, List<PipelineEdge>>{};
  for (final edge in pipeline.edges) {
    final a = edge.fromNodeId;
    final b = edge.toNodeId;
    byPair
        .putIfAbsent(a.compareTo(b) <= 0 ? '$a>$b' : '$b>$a', () => [])
        .add(edge);
  }
  final fractions = <String, double>{};
  for (final group in byPair.values) {
    if (group.length == 1) {
      fractions[group.first.id] = kLabelPosition;
      continue;
    }
    group.sort((x, y) => x.id.compareTo(y.id));
    for (var i = 0; i < group.length; i++) {
      final along =
          (kLabelPosition + _labelSpread * (i - (group.length - 1) / 2))
              .clamp(0.15, 0.85);
      fractions[group[i].id] =
          group[i].fromNodeId.compareTo(group[i].toNodeId) <= 0
              ? along
              : 1 - along;
    }
  }
  return fractions;
}

/// What a wire's label says.
///
/// Shared with the painter rather than worked out twice: a label placed by
/// measuring one string and drawn from another would be nudged clear of a card
/// by the wrong amount.
String flowLabelText(double flow, Item? item, RateDisplay rateDisplay) {
  final precision =
      rateDisplay == RateDisplay.perSecond && flow.abs() >= 100 ? 0 : 1;
  // A flow needing more than one pipe is worth seeing without clicking, since
  // it is the difference between a build that fits and one that does not.
  final runs = item == null ? 0 : Conduits.runsNeeded(flow, item.category);
  final suffix = runs > 1 ? '  ×$runs' : '';
  return (item?.formatRate(flow, rateDisplay, precision: precision) ??
          Unit.gramsPerSecond.format(flow, precision: precision)) +
      suffix;
}

/// The box a label takes up, background and all.
Size labelSize(String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: OniType.numberSmall),
    textDirection: TextDirection.ltr,
  )..layout();
  return Size(painter.width + 8, painter.height + 3);
}
