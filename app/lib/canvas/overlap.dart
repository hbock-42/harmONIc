import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import 'geometry.dart';

/// A card you cannot see, because another one is sitting on top of it.
///
/// Found while measuring something else: a build sent in had a Plastic output
/// card lying entirely inside a Glo Squid card — same column, and its whole
/// height within the other's. Nothing said so. You cannot click it, cannot
/// read its figures, and the wires into it appear to stop in mid-air, which is
/// the sort of thing that gets reported as a wire bug.
///
/// It is worth saying out loud rather than quietly nudging apart. Two cards
/// overlapping is sometimes deliberate — a build parked out of the way while
/// something else is worked on — and an app that silently rearranged a canvas
/// would be worse than one that mentions it.
@immutable
class HiddenCard {
  const HiddenCard({
    required this.hiddenId,
    required this.underId,
    required this.fraction,
  });

  /// The card underneath, which is the one nobody can see.
  final String hiddenId;

  /// The card on top of it.
  final String underId;

  /// How much of the hidden card is covered, from [kHiddenEnough] to 1.
  final double fraction;

  /// Where it should go to be clear of what is covering it.
  ///
  /// Straight down, far enough to clear the other card's bottom edge with a
  /// normal gap. Down rather than the nearest way out because a canvas reads
  /// in columns: a card that moves sideways has changed which stage of the
  /// build it looks like it belongs to, and one that moves down has not.
  static Offset clearOf(Rect hidden, Rect under) =>
      Offset(hidden.left, NodeLayout.snap(under.bottom + _gap));

  static const double _gap = 24;
}

/// How much of a card has to be covered before it counts as hidden.
///
/// Not any overlap at all: cards clipping each other by a few pixels is untidy
/// rather than wrong, and a warning that fires on every slightly crowded build
/// is one nobody reads. This is the fraction at which the thing is genuinely
/// unusable — most of it gone, including, at this size, its name.
const double kHiddenEnough = 0.6;

/// Every card mostly buried under another, worst first.
///
/// Which of two overlapping cards is the hidden one is not a judgement: the
/// canvas draws them in the order the pipeline lists them, so the earlier of
/// the pair is underneath. That is also why this reports pairs rather than
/// "these two overlap" — one of them is fine and the other is invisible.
List<HiddenCard> hiddenCards(
  Pipeline pipeline,
  ProcessSpec? Function(PipelineNode node) specOf,
) {
  final rects = <(String, Rect)>[];
  for (final node in pipeline.nodes) {
    final spec = specOf(node);
    if (spec != null) rects.add((node.id, NodeLayout.worldRect(node, spec)));
  }

  final found = <HiddenCard>[];
  for (var under = 0; under < rects.length; under++) {
    final (hiddenId, hidden) = rects[under];
    final area = hidden.width * hidden.height;
    if (area <= 0) continue;
    // Only the cards drawn after it can hide it.
    for (var over = under + 1; over < rects.length; over++) {
      final (overId, on) = rects[over];
      final shared = hidden.intersect(on);
      if (shared.isEmpty) continue;
      final fraction = (shared.width * shared.height) / area;
      if (fraction < kHiddenEnough) continue;
      found.add(HiddenCard(
        hiddenId: hiddenId,
        underId: overId,
        fraction: math.min(1, fraction),
      ));
      // One is enough to say. A card buried under three is still one card to
      // move, and three lines saying so is three times the noise for nothing.
      break;
    }
  }
  found.sort((a, b) => b.fraction.compareTo(a.fraction));
  return found;
}
