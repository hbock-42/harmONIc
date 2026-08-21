import 'dart:math' as math;

import 'item.dart';

/// What one pipe, rail or wire can actually carry.
///
/// A ratio that balances on paper is still unbuildable if the water between two
/// buildings needs three pipes and there is room for one. These are the numbers
/// that turn a correct answer into a build.
class Conduit {
  const Conduit(this.name, this.capacity, {this.plural});

  final String name;

  /// In the item's own unit per second: g/s for matter, W for power.
  final double capacity;

  final String? plural;

  String describe(int count) =>
      count == 1 ? name : '$count ${plural ?? '${name}s'}';
}

abstract final class Conduits {
  /// Every conduit runs on the same tick: one packet a second. A liquid packet
  /// holds 10 kg, a gas packet 1 kg, a conveyor packet 20 kg.
  static const Conduit liquidPipe = Conduit('liquid pipe', 10000);
  static const Conduit gasPipe = Conduit('gas pipe', 1000);
  static const Conduit conveyorRail = Conduit('conveyor rail', 20000);

  /// Wires, cheapest first — the first that fits is the one to build.
  static const List<Conduit> wires = [
    Conduit('Wire', 1000),
    Conduit('Conductive Wire', 2000),
    Conduit('Heavi-Watt Wire', 20000),
    Conduit('Heavi-Watt Conductive Wire', 50000),
  ];

  /// The conduit that carries this kind of thing, if any does. Heat, grooming
  /// slots and plant growth travel by no pipe at all.
  static Conduit? forCategory(ItemCategory category) => switch (category) {
        ItemCategory.liquid => liquidPipe,
        ItemCategory.gas => gasPipe,
        ItemCategory.solid => conveyorRail,
        ItemCategory.power => wires.first,
        _ => null,
      };

  /// How many parallel runs a flow needs. Zero for a flow of nothing, so an
  /// unused connection does not read as work to do.
  static int runsNeeded(double ratePerSecond, ItemCategory category) {
    final conduit = forCategory(category);
    if (conduit == null || ratePerSecond.abs() <= 1e-9) return 0;
    return (ratePerSecond.abs() / conduit.capacity).ceil();
  }

  /// The cheapest wire that carries this load on its own, or the biggest there
  /// is when even that will not do.
  static Conduit wireFor(double watts) {
    for (final wire in wires) {
      if (watts.abs() <= wire.capacity) return wire;
    }
    return wires.last;
  }

  /// How many of [wireFor]'s choice you would need in parallel.
  static int wireRunsNeeded(double watts) => watts.abs() <= 1e-9
      ? 0
      : math.max(1, (watts.abs() / wires.last.capacity).ceil());

  /// A sentence for the inspector: "2 liquid pipes", "Conductive Wire".
  static String? describe(double ratePerSecond, ItemCategory category) {
    if (category == ItemCategory.power) {
      if (ratePerSecond.abs() <= 1e-9) return null;
      final wire = wireFor(ratePerSecond);
      final runs = wireRunsNeeded(ratePerSecond);
      return runs > 1 ? '$runs × ${wire.name}' : wire.name;
    }
    final conduit = forCategory(category);
    final runs = runsNeeded(ratePerSecond, category);
    if (conduit == null || runs == 0) return null;
    return conduit.describe(runs);
  }
}
