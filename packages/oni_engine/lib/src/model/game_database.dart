import 'dart:convert';

import 'item.dart';
import 'process_spec.dart';

/// The loaded ONI reference data: every item and every process the app knows about.
class GameDatabase {
  GameDatabase({
    required Iterable<Item> items,
    required Iterable<ProcessSpec> processes,
    this.dataVersion = 'unversioned',
    this.gameBuild,
  })  : _items = {for (final i in items) i.id: i},
        _processes = {for (final p in processes) p.id: p};

  factory GameDatabase.fromJson(Map<String, dynamic> json) {
    final db = GameDatabase(
      dataVersion: json['dataVersion'] as String? ?? 'unversioned',
      gameBuild: json['gameBuild'] as String?,
      items: [
        for (final raw in (json['items'] as List<dynamic>? ?? const []))
          Item.fromJson(raw as Map<String, dynamic>),
      ],
      processes: [
        for (final raw in (json['processes'] as List<dynamic>? ?? const []))
          ProcessSpec.fromJson(raw as Map<String, dynamic>),
      ],
    );
    db.assertConsistent();
    return db;
  }

  factory GameDatabase.fromJsonString(String source) =>
      GameDatabase.fromJson(jsonDecode(source) as Map<String, dynamic>);

  final Map<String, Item> _items;
  final Map<String, ProcessSpec> _processes;
  final String dataVersion;
  final String? gameBuild;

  Iterable<Item> get items => _items.values;
  Iterable<ProcessSpec> get processes => _processes.values;

  Item? item(String id) => _items[id];
  ProcessSpec? process(String id) => _processes[id];

  Item itemOrThrow(String id) =>
      _items[id] ?? (throw ArgumentError('Unknown item "$id"'));
  ProcessSpec processOrThrow(String id) =>
      _processes[id] ?? (throw ArgumentError('Unknown process "$id"'));

  /// Can something offering [offered] be wired into a port asking for [wanted]?
  ///
  /// The same item always can. Beyond that, a class accepts any of its members
  /// — a Metal Refinery asking for Metal Ore takes the Iron Ore an Orehull
  /// sheds — and, going the other way, a port offering the class satisfies a
  /// port asking for one of its members, because a pile of unspecified ore is
  /// where the iron was going to come from anyway.
  bool accepts(String wanted, String offered) {
    if (wanted == offered) return true;
    if (_items[wanted]?.members.contains(offered) ?? false) return true;
    if (_items[offered]?.members.contains(wanted) ?? false) return true;
    return false;
  }

  /// Every process port must reference a known item.
  void assertConsistent() {
    final problems = <String>[];
    for (final spec in _processes.values) {
      for (final port in spec.ports) {
        if (!_items.containsKey(port.itemId)) {
          problems.add('process "${spec.id}" port "${port.id}" '
              'references unknown item "${port.itemId}"');
        }
      }
      for (final material in spec.buildCost.keys) {
        if (!_items.containsKey(material)) {
          problems.add('process "${spec.id}" is built of unknown material '
              '"$material"');
        }
      }
    }
    for (final item in _items.values) {
      for (final member in item.members) {
        if (!_items.containsKey(member)) {
          problems.add('item "${item.id}" contains unknown member "$member"');
        } else if (_items[member]!.isClass) {
          problems.add('item "${item.id}" contains "$member", which is itself '
              'a class — a class of classes has no useful meaning here');
        }
      }
    }
    if (problems.isNotEmpty) {
      throw StateError('Invalid game data:\n - ${problems.join('\n - ')}');
    }
  }

  /// Merges another database on top of this one (user-defined processes,
  /// DLC packs). Later definitions win.
  GameDatabase merge(GameDatabase other) => GameDatabase(
        dataVersion: other.dataVersion,
        gameBuild: other.gameBuild ?? gameBuild,
        items: {..._items, ...other._items}.values,
        processes: {..._processes, ...other._processes}.values,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dataVersion': dataVersion,
        if (gameBuild != null) 'gameBuild': gameBuild,
        'items': [for (final i in items) i.toJson()],
        'processes': [for (final p in processes) p.toJson()],
      };
}
