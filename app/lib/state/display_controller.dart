import 'package:flutter/foundation.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import '../storage/json_store.dart';

/// The packs this app knows about, and what to call them.
///
/// Keyed by the tag the data uses, so a spec belongs to a pack by saying so
/// rather than by anybody keeping a list of ids in step.
const Map<String, String> kContentPacks = <String, String>{
  'aquatic': 'Aquatic',
  'frosty': 'Frosty',
  'prehistoric': 'Prehistoric',
};

/// The engine holds the same set, because a synthesised supply node has to
/// inherit its item's pack long before any widget exists to filter it.
void _assertPacksAgree() {
  assert(
    kContentPacks.keys.toSet().difference(contentPackTags).isEmpty &&
        contentPackTags.difference(kContentPacks.keys.toSet()).isEmpty,
    'the app and the engine disagree about which packs exist',
  );
}

/// How the reader wants rates written, remembered between runs.
///
/// A view setting rather than part of any pipeline: the same build read per
/// second and per cycle is the same build.
class DisplayController extends ChangeNotifier {
  DisplayController(this._store) {
    _assertPacksAgree();
  }

  final JsonStore _store;
  RateDisplay _display = RateDisplay.perSecond;

  /// The packs whose content belongs in the palette.
  ///
  /// Two thirds of the catalogue is DLC, and a base-game player being offered a
  /// Tidal Turbine is being offered something they cannot build. Everything is
  /// on by default, because most people who install a pack keep it.
  final Set<String> _packs = {...kContentPacks.keys};

  /// Whether wild variants are offered. They double the length of the critter
  /// and plant lists, and most builds are farmed.
  bool _showWild = true;

  /// Dark unless somebody says otherwise. A tool people leave open beside a
  /// game that is itself dark should not be the bright thing on the desk.
  bool _light = false;

  RateDisplay get display => _display;
  Set<String> get packs => Set.unmodifiable(_packs);
  bool get showWild => _showWild;
  bool get isLight => _light;

  bool packEnabled(String pack) => _packs.contains(pack);

  /// Is this something the palette should offer, given what is switched on?
  bool includes(ProcessSpec spec) {
    if (!_showWild && spec.tags.contains('wild')) return false;
    for (final pack in kContentPacks.keys) {
      if (spec.tags.contains(pack) && !_packs.contains(pack)) return false;
    }
    return true;
  }

  /// The same question for an item. Materials carry pack tags as processes do,
  /// so a Frosty ingredient can be kept out of a custom recipe as easily as a
  /// Frosty building can be kept out of the palette.
  bool includesItem(Item item) {
    for (final pack in kContentPacks.keys) {
      if (item.tags.contains(pack) && !_packs.contains(pack)) return false;
    }
    return true;
  }

  Future<void> setPack(String pack, {required bool enabled}) async {
    if (enabled ? !_packs.add(pack) : !_packs.remove(pack)) return;
    notifyListeners();
    await _save();
  }

  Future<void> setLight({required bool light}) async {
    if (light == _light) return;
    _light = light;
    OniTheme.current = light ? OniPalette.light : OniPalette.dark;
    notifyListeners();
    await _save();
  }

  Future<void> setShowWild({required bool showWild}) async {
    if (showWild == _showWild) return;
    _showWild = showWild;
    notifyListeners();
    await _save();
  }

  /// The label for what a click would switch *to*, for a button that says
  /// where it takes you rather than where you are.
  String get otherLabel =>
      _display == RateDisplay.perSecond ? 'kg/cycle' : 'g/s';

  String get currentLabel =>
      _display == RateDisplay.perSecond ? 'g/s' : 'kg/cycle';

  Future<void> load() async {
    final raw = await _store.read();
    final saved = raw?['rateDisplay'] as String?;
    if (saved == RateDisplay.perCycle.name) {
      _display = RateDisplay.perCycle;
    }
    final packs = raw?['packs'] as List<dynamic>?;
    if (packs != null) {
      _packs
        ..clear()
        ..addAll(packs.cast<String>().where(kContentPacks.containsKey));
    }
    _showWild = raw?['showWild'] as bool? ?? true;
    _light = raw?['light'] as bool? ?? false;
    OniTheme.current = _light ? OniPalette.light : OniPalette.dark;
    notifyListeners();
  }

  Future<void> toggle() => set(_display.other);

  Future<void> set(RateDisplay display) async {
    if (display == _display) return;
    _display = display;
    notifyListeners();
    await _save();
  }

  Future<void> _save() => _store.write(<String, dynamic>{
        'rateDisplay': _display.name,
        'packs': _packs.toList(),
        'showWild': _showWild,
        'light': _light,
      });
}
