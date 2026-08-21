import 'package:flutter/foundation.dart';
import 'package:oni_engine/oni_engine.dart';

import '../storage/json_store.dart';

/// The process catalogue: what ships with the app, plus whatever the player has
/// added or corrected on top of it.
///
/// The wiki lags every DLC, and some numbers it simply never publishes. Rather
/// than making people wait for a release, a definition saved here overrides the
/// bundled one by id, and anything new is merged in alongside.
class LibraryController extends ChangeNotifier {
  LibraryController({
    required GameDatabase bundled,
    required JsonStore store,
  })  : _bundled = bundled,
        _database = bundled,
        // A named parameter cannot be written `this._store`.
        // ignore: prefer_initializing_formals
        _store = store;

  final GameDatabase _bundled;
  final JsonStore _store;

  GameDatabase _database;
  final Map<String, ProcessSpec> _customProcesses = {};
  final Map<String, Item> _customItems = {};

  /// Bundled data with the player's definitions merged over it.
  GameDatabase get database => _database;

  GameDatabase get bundled => _bundled;

  Iterable<ProcessSpec> get customProcesses => _customProcesses.values;

  /// True when this id came from the player rather than the shipped data.
  bool isCustom(String specId) => _customProcesses.containsKey(specId);

  /// True when the player's version replaces one that ships with the app —
  /// worth saying out loud, because it means their numbers win.
  bool isOverride(String specId) =>
      _customProcesses.containsKey(specId) && _bundled.process(specId) != null;

  Future<void> load() async {
    final raw = await _store.read();
    if (raw == null) {
      _rebuild();
      return;
    }
    try {
      for (final entry in (raw['items'] as List<dynamic>? ?? const [])) {
        final item = Item.fromJson(entry as Map<String, dynamic>);
        _customItems[item.id] = item;
      }
      for (final entry in (raw['processes'] as List<dynamic>? ?? const [])) {
        final spec = ProcessSpec.fromJson(entry as Map<String, dynamic>);
        _customProcesses[spec.id] = spec;
      }
    } on Object {
      // Keep whatever parsed; a half-readable file beats refusing to start.
      _customProcesses.removeWhere((_, spec) => false);
    }
    _rebuild();
  }

  /// Saves one definition, along with any items it needs that did not exist.
  Future<void> save(ProcessSpec spec, {Iterable<Item> newItems = const []}) async {
    for (final item in newItems) {
      _customItems[item.id] = item;
    }
    _customProcesses[spec.id] = spec;
    _rebuild();
    await _persist();
  }

  /// Removes a player definition. A bundled process this was overriding comes
  /// back, rather than disappearing.
  Future<void> revert(String specId) async {
    _customProcesses.remove(specId);
    _rebuild();
    await _persist();
  }

  Future<void> _persist() => _store.write(<String, dynamic>{
        'schemaVersion': 1,
        'items': [for (final i in _customItems.values) i.toJson()],
        'processes': [for (final p in _customProcesses.values) p.toJson()],
      });

  void _rebuild() {
    _database = GameDatabase(
      dataVersion: _bundled.dataVersion,
      gameBuild: _bundled.gameBuild,
      items: {
        for (final i in _bundled.items) i.id: i,
        ..._customItems,
      }.values,
      processes: {
        for (final p in _bundled.processes) p.id: p,
        ..._customProcesses,
      }.values,
    );
    notifyListeners();
  }

  /// A blank definition to start editing from.
  ProcessSpec draft({String? id}) => ProcessSpec(
        id: id ?? 'custom_${DateTime.now().microsecondsSinceEpoch}',
        name: 'New process',
        kind: ProcessKind.building,
        ports: const [],
        tags: const {'custom', 'unverified'},
        description: 'UNVERIFIED: added by hand.',
      );

  /// A copy of an existing process, ready to be edited into an override.
  ProcessSpec editable(ProcessSpec spec) => ProcessSpec(
        id: spec.id,
        name: spec.name,
        kind: spec.kind,
        buildingId: spec.buildingId,
        description: spec.description,
        ports: spec.ports,
        dupeLabourSecondsPerCycle: spec.dupeLabourSecondsPerCycle,
        footprintWidth: spec.footprintWidth,
        footprintHeight: spec.footprintHeight,
        tags: {...spec.tags, 'custom'},
      );
}
