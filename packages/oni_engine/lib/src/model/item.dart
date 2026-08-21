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
        ItemCategory.entity || ItemCategory.other => Unit.count,
      };

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
