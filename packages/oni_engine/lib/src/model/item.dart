import 'units.dart';

/// What kind of thing flows along an edge.
enum ItemCategory {
  solid,
  liquid,
  gas,
  power,
  heat,
  /// Duplicants, critters, plants — things that are *present* rather than flowing.
  entity,

  /// A capacity rather than a flow: a grooming slot, a milking slot. Eight of
  /// them is eight, whether you look at a second or a cycle, so these are the
  /// one thing that must never be scaled by time.
  service,
  other;

  static ItemCategory parse(String raw) => ItemCategory.values.firstWhere(
        (c) => c.name == raw,
        orElse: () => throw FormatException('Unknown item category "$raw"'),
      );
}

/// A resource that can be produced or consumed: Water, Oxygen, Coal, Power, Heat…
class Item {
  const Item({
    required this.id,
    required this.name,
    required this.category,
    this.tags = const {},
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String,
        name: json['name'] as String,
        category: ItemCategory.parse(json['category'] as String),
        tags: {...(json['tags'] as List<dynamic>? ?? const []).cast<String>()},
      );

  final String id;
  final String name;
  final ItemCategory category;
  final Set<String> tags;

  Unit get unit => switch (category) {
        ItemCategory.solid ||
        ItemCategory.liquid ||
        ItemCategory.gas =>
          Unit.gramsPerSecond,
        ItemCategory.power => Unit.watts,
        ItemCategory.heat => Unit.kdtuPerSecond,
        ItemCategory.entity ||
        ItemCategory.service ||
        ItemCategory.other =>
          Unit.count,
      };

  /// A capacity, not a flow — see [ItemCategory.service].
  bool get isCapacity => category == ItemCategory.service;

  /// Formats a per-second [value] the way the reader asked to see it.
  ///
  /// Per cycle, mass becomes kg, power becomes the kilojoules a cycle of it
  /// actually delivers, and a trickle like one egg every six cycles finally
  /// reads as a number a person can picture.
  String formatRate(
    double value,
    RateDisplay display, {
    int precision = 2,
  }) {
    if (isCapacity) return value.toStringAsFixed(precision);
    if (display == RateDisplay.perSecond) {
      return unit.format(value, precision: precision);
    }
    final perCycle = value * secondsPerCycle;
    return switch (unit) {
      Unit.gramsPerSecond => perCycle.abs() >= 1000
          ? '${(perCycle / 1000).toStringAsFixed(precision)} kg/cycle'
          : '${perCycle.toStringAsFixed(precision)} g/cycle',
      Unit.watts => '${(perCycle / 1000).toStringAsFixed(precision)} kJ/cycle',
      Unit.kdtuPerSecond =>
        '${perCycle.toStringAsFixed(precision)} kDTU/cycle',
      Unit.count => '${perCycle.toStringAsFixed(precision)} /cycle',
    };
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'category': category.name,
        if (tags.isNotEmpty) 'tags': tags.toList(),
      };

  @override
  String toString() => 'Item($id)';
}

/// Well-known item ids the engine itself reasons about.
abstract final class WellKnownItems {
  static const String power = 'power';
  static const String heat = 'heat';
}
