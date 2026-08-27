import 'package:flutter/foundation.dart';

import '../panels/changelog_panel.dart';
import '../panels/guide_panel.dart';
import '../storage/json_store.dart';

/// Whether there is anything new to tell somebody, and remembering that they
/// have been told.
///
/// The news is the changelog's newest entry, not the build. A deploy that
/// fixed a typo has nothing to say, and interrupting somebody to say it is how
/// a notice becomes something people dismiss without reading. No entry, no
/// news.
class NewsController extends ChangeNotifier {
  NewsController({required this.store, Future<String> Function()? load})
      : _load = load ?? loadChangelog;

  final JsonStore store;
  final Future<String> Function() _load;

  String? _latest;
  String? _seen;
  bool _ready = false;

  /// The heading of an entry nobody here has read yet, or null.
  String? get unread =>
      _ready && _latest != null && _latest != _seen ? _latest : null;

  /// What they had read last time, so the panel can show them only what came
  /// after it. Held past [markSeen] on purpose: marking it read the moment
  /// they open it must not empty the thing they just opened.
  String? get since => _wasSeen;
  String? _wasSeen;

  /// How many entries are new to them, or null when it cannot be told —
  /// the entry they last read has been renamed or removed since.
  int? get unreadCount {
    if (unread == null) return null;
    final at = _entries.indexWhere((title) => title == _seen);
    return at < 0 ? null : at;
  }

  List<String> _entries = const [];

  /// The text, once it has loaded, so the panel does not fetch it twice.
  String? get changelog => _changelog;
  String? _changelog;

  Future<void> load() async {
    final saved = await store.read();
    _seen = saved?['seen'] as String?;
    try {
      _changelog = await _load();
      _entries = releaseTitles(_changelog!);
      _latest = _entries.isEmpty ? null : _entries.first;
    } on Object {
      // A changelog that will not load is not worth an error on somebody's
      // canvas. They came here to plan a base.
      _latest = null;
    }
    _ready = true;
    _wasSeen = _seen;

    // Nothing stored means somebody has just arrived, and "what's new" to
    // them is all of it. Record where they came in and say nothing.
    if (_seen == null && _latest != null) {
      _seen = _latest;
      await store.write({'seen': _latest});
    }
    notifyListeners();
  }

  Future<void> markSeen() async {
    if (_latest == null || _latest == _seen) return;
    _seen = _latest;
    await store.write({'seen': _seen});
    notifyListeners();
  }
}
