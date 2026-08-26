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
    this.members = const {},
    this.refinesTo,
    this.specificHeat,
    this.kcalPerKg,
    this.tags = const {},
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String,
        name: json['name'] as String,
        category: ItemCategory.parse(json['category'] as String),
        members: {
          ...(json['members'] as List<dynamic>? ?? const []).cast<String>(),
        },
        refinesTo: json['refinesTo'] as String?,
        specificHeat: (json['specificHeat'] as num?)?.toDouble(),
        kcalPerKg: (json['kcalPerKg'] as num?)?.toDouble(),
        tags: {...(json['tags'] as List<dynamic>? ?? const []).cast<String>()},
      );

  final String id;
  final String name;
  final ItemCategory category;

  /// The concrete items this one stands for, if it is a class rather than a
  /// thing: "Metal Ore" is any of a dozen ores, and a Metal Refinery does not
  /// care which. Empty for an ordinary item.
  ///
  /// A class is a *compatibility* rule, not a new kind of flow. Everything here
  /// is already measured in grams, so a port asking for Metal Ore and a port
  /// offering Iron Ore balance without the solver knowing the difference. What
  /// the class buys is one Metal Refinery in the palette instead of a dozen.
  final Set<String> members;

  bool get isClass => members.isNotEmpty;

  /// Counted in ones rather than weighed: gaskets, eggs, Duplicants.
  ///
  /// Four kinds of arithmetic ask this — what to leave out of a mass total,
  /// what a building is really made of, what one of something costs, and how
  /// to write it down — and each of them used to ask it in its own words.
  bool get isCounted => unit == Unit.count;

  /// Matter: something with a weight that a balance sheet must account for.
  ///
  /// Power and heat are ordinary items here so that a grid balances like
  /// anything else, but they weigh nothing, and neither does a grooming slot
  /// or a plant's growth. The mass-balance audit is the thing that cares.
  bool get hasMass => const {
        ItemCategory.solid,
        ItemCategory.liquid,
        ItemCategory.gas,
      }.contains(category);

  /// What this becomes in a refinery: iron ore makes iron, and nothing else.
  final String? refinesTo;

  /// (DTU/g)/°C — how much heat a gram of this holds per degree.
  ///
  /// The number that decides what happens when two flows meet: a kilogram of
  /// 90 °C water and a kilogram of 20 °C water make two kilograms at 55 °C,
  /// but a kilogram of hot water and a kilogram of cold oil do not meet in the
  /// middle at all, because water holds two and a half times the heat.
  ///
  /// Null for anything not measured yet, and for things where it has no
  /// meaning — power, heat, a grooming slot.
  final double? specificHeat;

  /// How many kilocalories a kilogram of this feeds somebody, for the things
  /// somebody eats.
  ///
  /// A cooked dish is a material here — a Gas Range takes two kilograms of
  /// Gristle Berry the way a Kiln takes two hundred of wood — so somewhere the
  /// kilograms have to become the calories a Duplicant actually consumes. This
  /// is that number, and `docs/FOOD.md` is why it is on the item rather than
  /// on every recipe that makes one.
  ///
  /// Null for anything nobody eats.
  final double? kcalPerKg;

  bool get isFood => kcalPerKg != null;

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

  /// Enough decimal places that a real rate is not printed as nothing.
  ///
  /// A Hatch lays an egg every 1.4 cycles, which is 0.0024 a second, which at
  /// two decimal places is "0.00" — and "0.00" does not mean "a small number",
  /// it means "none". A ranch reporting no eggs is worse than one reporting an
  /// awkward figure. Capped, because past a point the honest answer is that the
  /// number is too small to matter and the extra digits are noise.
  static int _enoughDigitsFor(double value, int precision) {
    final magnitude = value.abs();
    if (magnitude == 0) return precision;
    var digits = precision;
    while (digits < 6 && magnitude < 0.5 / _powerOfTen(digits)) {
      digits++;
    }
    return digits;
  }

  static double _powerOfTen(int n) {
    var result = 1.0;
    for (var i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }

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
    precision = _enoughDigitsFor(
        display == RateDisplay.perSecond ? value : value * secondsPerCycle,
        precision);
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
        if (members.isNotEmpty) 'members': members.toList(),
        if (refinesTo != null) 'refinesTo': refinesTo,
        if (specificHeat != null) 'specificHeat': specificHeat,
        if (kcalPerKg != null) 'kcalPerKg': kcalPerKg,
        if (tags.isNotEmpty) 'tags': tags.toList(),
      };

  @override
  String toString() => 'Item($id)';
}

/// Well-known item ids the engine itself reasons about.
abstract final class WellKnownItems {
  static const String power = 'power';
  static const String heat = 'heat';

  /// What a Duplicant actually eats. Every dish is a material until somebody
  /// puts it on a plate; see `docs/FOOD.md`.
  static const String calories = 'calories';
}
