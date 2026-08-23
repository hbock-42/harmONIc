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
    // Editing a recipe can orphan a material as surely as deleting one.
    _forgetUnusedItems();
    _rebuild();
    await _persist();
  }

  /// Removes a player definition. A bundled process this was overriding comes
  /// back, rather than disappearing.
  Future<void> revert(String specId) async {
    _customProcesses.remove(specId);
    _forgetUnusedItems();
    _rebuild();
    await _persist();
  }

  /// An invented material lives as long as a recipe of yours uses it.
  ///
  /// Inventing one is a keystroke — type a name nobody has heard of and press
  /// Create — and it used to be for ever: nothing removed it, and since it now
  /// gets a supply, an output and a pump of its own, one typo left five
  /// entries in the palette with no way to be rid of them.
  ///
  /// Only *your* items are ever forgotten, and only when nothing written by
  /// you mentions them any more.
  void _forgetUnusedItems() {
    final used = <String>{
      for (final spec in _customProcesses.values) ...[
        for (final port in spec.ports) port.itemId,
        for (final port in spec.ports) ...port.alternatives,
        ...spec.buildCost.keys,
      ],
    };
    // A class somebody invented counts as using its members.
    for (final item in _customItems.values) {
      if (used.contains(item.id)) used.addAll(item.members);
    }
    _customItems.removeWhere((id, _) => !used.contains(id));
  }

  /// Everything the player has written, packed up to hand to somebody else.
  ///
  /// The items travel with the processes: a recipe for a material this app has
  /// never heard of arrives broken without them, and that is the usual reason
  /// somebody had to write the recipe in the first place.
  RecipePack get pack => RecipePack(
        items: _customItems.values.toList(),
        processes: _customProcesses.values.toList(),
      );

  /// Merges somebody else's pack in, and says what it did.
  ///
  /// Their recipes win where the ids collide, which is what importing means —
  /// but the count says how many were replaced rather than added, because
  /// quietly overwriting an evening's measuring would be the one unforgivable
  /// thing this could do.
  Future<({int added, int replaced})> import(RecipePack incoming) async {
    var added = 0;
    var replaced = 0;
    for (final spec in incoming.processes) {
      if (_customProcesses.containsKey(spec.id)) {
        replaced++;
      } else {
        added++;
      }
      _customProcesses[spec.id] = spec;
    }
    for (final item in incoming.items) {
      _customItems[item.id] = item;
    }
    _rebuild();
    await _persist();
    return (added: added, replaced: replaced);
  }

  Future<void> _persist() => _store.write(pack.toJson());

  void _rebuild() {
    // Generated afterwards rather than merged in: an item somebody invented
    // needs a supply and an output like any other, and the bundled database
    // cannot have made them because the item did not exist yet. Without this
    // a custom material was a dead end — nothing could feed the recipe that
    // asked for it, not even "I have some".
    _database = withGeneratedNodes(GameDatabase(
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
    ));
    notifyListeners();
  }

  /// A blank definition to start editing from.
  ProcessSpec draft({String? id, List<Port> ports = const []}) => ProcessSpec(
        id: id ?? 'custom_${DateTime.now().microsecondsSinceEpoch}',
        name: 'New process',
        kind: ProcessKind.building,
        ports: ports,
        tags: const {'custom', 'unverified'},
        description: 'UNVERIFIED: added by hand.',
      );

  /// A draft that already answers the port somebody was looking at.
  ///
  /// Reached from "nothing here makes that": the form opens knowing what was
  /// wanted, so the first line is filled in and only the rate is missing. What
  /// fills an *input* is something that produces, and the other way round.
  ProcessSpec draftFor(Port port) => draft(ports: [
        Port(
          id: port.itemId,
          itemId: port.itemId,
          direction:
              port.isInput ? PortDirection.output : PortDirection.input,
          ratePerSecond: 0,
        ),
      ]);

  /// A copy of an existing process, ready to be edited into an override.
  ///
  /// Everything comes across, including the parts the form has no field for.
  /// It dropped the build cost and the overheat rating for a while, so
  /// correcting a Metal Refinery's rates made a refinery built out of nothing
  /// and the shopping list quietly lost 800 kg of rock.
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
        buildCost: spec.buildCost,
        overheatCelsius: spec.overheatCelsius,
        tags: {...spec.tags, 'custom'},
      );
}
