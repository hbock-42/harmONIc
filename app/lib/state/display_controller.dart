import 'package:flutter/foundation.dart';
import 'package:oni_engine/oni_engine.dart';

import '../storage/json_store.dart';

/// How the reader wants rates written, remembered between runs.
///
/// A view setting rather than part of any pipeline: the same build read per
/// second and per cycle is the same build.
class DisplayController extends ChangeNotifier {
  DisplayController(this._store);

  final JsonStore _store;
  RateDisplay _display = RateDisplay.perSecond;

  RateDisplay get display => _display;

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
      notifyListeners();
    }
  }

  Future<void> toggle() => set(_display.other);

  Future<void> set(RateDisplay display) async {
    if (display == _display) return;
    _display = display;
    notifyListeners();
    await _store.write(<String, dynamic>{'rateDisplay': display.name});
  }
}
