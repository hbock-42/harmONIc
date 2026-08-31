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

  /// The other things this same thing can be set to be.
  ///
  /// One building often has several recipes — a Rock Crusher makes sand or
  /// lime or metal, an Aquatuner is one machine per coolant — and each is its
  /// own spec, because their rates differ and a rate is what a spec is. They
  /// are the same *building* though, which is why they share a `buildingId`,
  /// and swapping between them should not mean deleting what you placed.
  ///
  /// The same is true of a creature or a plant kept a different way: a Hatch
  /// and a Hatch (wild) are one animal, and an Arbor Tree comes four ways once
  /// grazing is counted. Those share a `family`.
  ///
  /// Includes the one asked about, and is empty for anything that stands
  /// alone.
  List<ProcessSpec> variantsOf(ProcessSpec spec) {
    // Two ways of being the same thing, and they mean the same to a reader:
    // a building running a different coolant, and a creature kept a different
    // way. The second had no answer at all until somebody asked for "toggles
    // for grooming, with the same format as plants" -- and changing your mind
    // about it meant deleting the card and drawing its wires again.
    final key = spec.family ?? spec.buildingId;
    if (key == null) return const [];
    final found = [
      for (final other in processes)
        if ((other.family ?? other.buildingId) == key) other,
    ]..sort((a, b) => a.name.compareTo(b.name));
    return found.length > 1 ? found : const [];
  }

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
      for (final port in spec.ports) {
        // A port that names an input it depends on has to name one that is
        // there. Nothing else would notice: an output whose `needs` points at
        // a port that does not exist is simply never switched off, so the
        // typo shows up as a feature quietly not working.
        if (port.withoutFactor != 0 && port.needsPortId == null) {
          problems.add('process "${spec.id}" port "${port.id}" says what is '
              'left of it without something, and does not say without what');
        }
        if (port.withoutFactor < 0 || port.withoutFactor > 1) {
          problems.add('process "${spec.id}" port "${port.id}" keeps '
              '${port.withoutFactor} of itself, which is not a fraction');
        }
        // The same trap in the happiness form: a rate quoted at a happiness
        // nothing on this thing can reach is a rate that never varies, so the
        // mistake reads as a critter that ignores its Condo.
        if (port.happinessAt != null && !port.isOutput) {
          problems.add('process "${spec.id}" port "${port.id}" is an input '
              'and cannot be priced in happiness: only what comes out varies '
              'with it');
        }
        if (port.happiness != 0 && !port.isInput) {
          problems.add('process "${spec.id}" port "${port.id}" is an output '
              'and cannot buy happiness');
        }
        if (port.happinessAt != null &&
            !spec.ports.any((p) => p.isInput && p.happiness != 0)) {
          problems.add('process "${spec.id}" port "${port.id}" is priced in '
              'happiness and nothing here buys any');
        }
        if (port.needsPortId case final String needed) {
          final target = spec.portById(needed);
          if (target == null) {
            problems.add('process "${spec.id}" port "${port.id}" needs '
                '"$needed", which it has not got');
          } else if (!target.isInput) {
            problems.add('process "${spec.id}" port "${port.id}" needs '
                '"$needed", which is an output — a thing can only depend on '
                'something coming in');
          } else if (!port.isOutput) {
            problems.add('process "${spec.id}" port "${port.id}" is an input '
                'and cannot depend on "$needed": only what comes out can stop '
                'coming out');
          }
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
