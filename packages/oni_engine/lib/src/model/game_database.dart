import 'dart:convert';

import 'build_material.dart';
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
        if (!BuildMaterials.isKnown(material)) {
          problems.add('process "${spec.id}" is built of unknown material '
              '"$material"');
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
